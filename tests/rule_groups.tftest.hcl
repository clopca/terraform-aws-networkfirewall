mock_provider "aws" {
  override_during = plan
  mock_resource "aws_networkfirewall_rule_group" {
    defaults = {
      arn          = "arn:aws:network-firewall:us-east-1:123456789012:stateful-rulegroup/mock"
      id           = "mock"
      update_token = "token"
    }
  }
}

variables {
  rule_groups = {
    egress = {
      name       = "egress-v1"
      type       = "STATEFUL"
      capacity   = 200
      rule_order = "STRICT_ORDER"
      source = {
        rules_string = <<-RULES
          alert tcp $HOME_NET any -> any $WEB_PORTS (msg:"observe"; sid:1001; rev:1;)
          drop tcp $HOME_NET any -> any 23 (msg:"block"; sid:1002; rev:1;)
        RULES
      }
      ip_sets            = { HOME_NET = ["10.0.0.0/8"] }
      port_sets          = { WEB_PORTS = ["80", "443"] }
      required_ip_sets   = ["HOME_NET"]
      required_port_sets = ["WEB_PORTS"]
      requires_home_net  = true
      sid_range          = { min = 1000, max = 1099 }
      source_validation  = { mode = "attested", manifest_uri = "s3://evidence/egress-v1.json", bundle_sha256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" }
    }
  }
}

run "create_suricata_group_with_typed_sets" {
  command = plan
  module { source = "./modules/rule-groups" }
  assert {
    condition = (
      length(aws_networkfirewall_rule_group.terraform_content) == 1 &&
      length(aws_networkfirewall_rule_group.external_content) == 0 &&
      output.rule_group_records.egress.validation_mode == "attested" &&
      output.rule_group_records.egress.requires_home_net
    )
    error_message = "The Suricata lane must publish typed-set, validation, and HOME_NET metadata."
  }
  assert {
    condition     = length(aws_networkfirewall_rule_group.terraform_content["egress"].encryption_configuration) == 0
    error_message = "AWS-owned encryption must omit the provider block."
  }
}

run "render_customer_kms" {
  command = plan
  module { source = "./modules/rule-groups" }
  variables {
    rule_groups = {
      kms = {
        name              = "kms-v1", type = "STATEFUL", capacity = 10
        source            = { rules_string = "alert ip any any -> any any (sid:2001;)" }
        source_validation = { mode = "aws_apply" }
        encryption        = { type = "CUSTOMER_KMS", key_arn = "arn:aws:kms:us-east-1:123456789012:key/abc" }
      }
    }
  }
  assert {
    condition     = one(aws_networkfirewall_rule_group.terraform_content["kms"].encryption_configuration).type == "CUSTOMER_KMS"
    error_message = "Customer KMS must render the encryption block."
  }
}

run "create_domain_list_lane" {
  command = plan
  module { source = "./modules/rule-groups" }
  variables {
    rule_groups = {
      domains = {
        name              = "domains-v1", type = "STATEFUL", capacity = 100
        source            = { rules_source_list = { generated_rules_type = "ALLOWLIST", target_types = ["TLS_SNI", "HTTP_HOST"], targets = [".example.com"] } }
        source_validation = { mode = "aws_apply" }
      }
    }
  }
  assert {
    condition     = output.rule_group_records.domains.requires_home_net
    error_message = "Generated ALLOWLIST metadata must require policy HOME_NET."
  }
}

run "create_native_stateful_lane" {
  command = plan
  module { source = "./modules/rule-groups" }
  variables {
    rule_groups = {
      native = {
        name = "native-v1", type = "STATEFUL", capacity = 10
        source = { stateful_rules = {
          dns = {
            action  = "ALERT"
            header  = { protocol = "UDP", source = "ANY", source_port = "ANY", direction = "FORWARD", destination = "ANY", destination_port = "53" }
            options = { sid = { keyword = "sid", settings = ["3001"] } }
          }
        } }
        source_validation = { mode = "aws_apply" }
      }
    }
  }
  assert {
    condition     = length(aws_networkfirewall_rule_group.terraform_content["native"].rule_group[0].rules_source[0].stateful_rule) == 1
    error_message = "The native stateful map must render one stable rule."
  }
}

run "create_stateless_lane" {
  command = plan
  module { source = "./modules/rule-groups" }
  variables {
    rule_groups = {
      stateless = {
        name = "stateless-v1", type = "STATELESS", capacity = 10
        source = { stateless_rules = {
          hygiene = { priority = 10, actions = ["aws:drop"], match = { destinations = ["192.0.2.0/24"], protocols = [6] } }
        } }
        source_validation = { mode = "aws_apply" }
      }
    }
  }
  assert {
    condition     = length(aws_networkfirewall_rule_group.terraform_content["stateless"].rule_group[0].rules_source[0].stateless_rules_and_custom_actions[0].stateless_rule) == 1
    error_message = "The stateless map must render one stable rule."
  }
}

run "inject_with_declared_metadata" {
  command = plan
  module { source = "./modules/rule-groups" }
  variables {
    rule_groups = {
      managed = {
        create   = false
        arn      = "arn:aws:network-firewall:us-east-1:aws-managed:stateful-rulegroup/ThreatSignaturesStrictOrder"
        metadata = { type = "STATEFUL", rule_order = "STRICT_ORDER", declared_capacity = 1000, kind = "managed" }
      }
    }
  }
  assert {
    condition     = length(aws_networkfirewall_rule_group.terraform_content) == 0 && output.rule_group_records.managed.kind == "managed"
    error_message = "Injected groups must create nothing and publish caller-attested metadata."
  }
}

run "reject_missing_required_ip_set" {
  command = plan
  module { source = "./modules/rule-groups" }
  variables { rule_groups = { bad = { name = "bad", type = "STATEFUL", capacity = 10, source = { rules_string = "alert ip $HOME_NET any -> any any (sid:1;)" }, required_ip_sets = ["HOME_NET"], source_validation = { mode = "aws_apply" } } } }
  expect_failures = [terraform_data.rule_group_contract["bad"]]
}

run "reject_empty_required_port_set" {
  command = plan
  module { source = "./modules/rule-groups" }
  variables { rule_groups = { bad = { name = "bad", type = "STATEFUL", capacity = 10, source = { rules_string = "alert tcp any any -> any $PORTS (sid:1;)" }, port_sets = { PORTS = [] }, required_port_sets = ["PORTS"], source_validation = { mode = "aws_apply" } } } }
  expect_failures = [terraform_data.rule_group_contract["bad"]]
}

run "reject_duplicate_suricata_sid" {
  command = plan
  module { source = "./modules/rule-groups" }
  variables { rule_groups = { bad = { name = "bad", type = "STATEFUL", capacity = 10, source = { rules_string = "alert ip any any -> any any (sid:9;)\ndrop ip any any -> any any (sid:9;)" }, source_validation = { mode = "aws_apply" } } } }
  expect_failures = [terraform_data.rule_group_contract["bad"]]
}

run "reject_sid_outside_range" {
  command = plan
  module { source = "./modules/rule-groups" }
  variables { rule_groups = { bad = { name = "bad", type = "STATEFUL", capacity = 10, source = { rules_string = "alert ip any any -> any any (sid:99;)" }, sid_range = { min = 100, max = 199 }, source_validation = { mode = "aws_apply" } } } }
  expect_failures = [terraform_data.rule_group_contract["bad"]]
}

run "reject_capacity_outside_quota" {
  command = plan
  module { source = "./modules/rule-groups" }
  variables { rule_groups = { bad = { name = "bad", type = "STATEFUL", capacity = 30001, source = { rules_string = "alert ip any any -> any any (sid:1;)" }, source_validation = { mode = "aws_apply" } } } }
  expect_failures = [terraform_data.rule_group_contract["bad"]]
}

run "reject_multiple_source_lanes" {
  command = plan
  module { source = "./modules/rule-groups" }
  variables { rule_groups = { bad = { name = "bad", type = "STATEFUL", capacity = 10, source = { rules_string = "alert ip any any -> any any (sid:1;)", rules_source_list = { generated_rules_type = "DENYLIST", target_types = ["TLS_SNI"], targets = [".example.com"] } }, source_validation = { mode = "aws_apply" } } } }
  expect_failures = [terraform_data.rule_group_contract["bad"]]
}

run "reject_source_type_mismatch" {
  command = plan
  module { source = "./modules/rule-groups" }
  variables { rule_groups = { bad = { name = "bad", type = "STATELESS", capacity = 10, source = { rules_string = "alert ip any any -> any any (sid:1;)" }, source_validation = { mode = "aws_apply" } } } }
  expect_failures = [terraform_data.rule_group_contract["bad"]]
}

run "reject_action_order" {
  command = plan
  module { source = "./modules/rule-groups" }
  variables { rule_groups = { bad = { name = "bad", type = "STATEFUL", capacity = 10, rule_order = "DEFAULT_ACTION_ORDER", source = { rules_string = "alert ip any any -> any any (sid:1;)" }, source_validation = { mode = "aws_apply" } } } }
  expect_failures = [terraform_data.rule_group_contract["bad"]]
}

run "reject_incomplete_attestation" {
  command = plan
  module { source = "./modules/rule-groups" }
  variables { rule_groups = { bad = { name = "bad", type = "STATEFUL", capacity = 10, source = { rules_string = "alert ip any any -> any any (sid:1;)" }, source_validation = { mode = "attested", bundle_sha256 = "abc" } } } }
  expect_failures = [terraform_data.rule_group_contract["bad"]]
}

run "reject_duplicate_stateless_priority" {
  command = plan
  module { source = "./modules/rule-groups" }
  variables {
    rule_groups = { bad = {
      name = "bad", type = "STATELESS", capacity = 10, source_validation = { mode = "aws_apply" }
      source = { stateless_rules = {
        one = { priority = 10, actions = ["aws:drop"], match = {} }
        two = { priority = 10, actions = ["aws:pass"], match = {} }
      } }
    } }
  }
  expect_failures = [terraform_data.rule_group_contract["bad"]]
}

run "reject_invalid_injected_metadata" {
  command = plan
  module { source = "./modules/rule-groups" }
  variables { rule_groups = { bad = { create = false, arn = "arn:example", metadata = { type = "STATEFUL", rule_order = "DEFAULT_ACTION_ORDER", declared_capacity = 0, kind = "customer" } } } }
  expect_failures = [terraform_data.rule_group_contract["bad"]]
}
