mock_provider "aws" {
  override_during = plan
  mock_resource "aws_networkfirewall_firewall_policy" {
    defaults = {
      arn          = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/mock"
      id           = "mock"
      update_token = "token"
    }
  }
}

variables {
  policies = {
    release-2026-08-13-plain = {
      name           = "inspection-release-2026-08-13-plain"
      enforcement    = { mode = "observation" }
      home_net_cidrs = ["10.0.0.0/8"]
      stateful_rule_groups = {
        managed = {
          arn      = "arn:aws:network-firewall:us-east-1:aws-managed:stateful-rulegroup/ThreatStrictOrder"
          priority = 100, kind = "managed", rule_order = "STRICT_ORDER", declared_capacity = 1000, enforce_from = "enforce"
          behavior = { actions = ["alert", "drop"], has_terminal_action = false, override_coverage = "all_blocking" }
        }
        customer = {
          arn             = "arn:aws:network-firewall:us-east-1:123456789012:stateful-rulegroup/customer-enforce"
          observation_arn = "arn:aws:network-firewall:us-east-1:123456789012:stateful-rulegroup/customer-observe"
          priority        = 200, kind = "customer", rule_order = "STRICT_ORDER", declared_capacity = 500, enforce_from = "selective", requires_home_net = true
          behavior        = { actions = ["alert", "drop", "pass"], has_terminal_action = true, override_coverage = "all_blocking" }
        }
      }
      stateless_rule_groups = {
        hygiene = { arn = "arn:aws:network-firewall:us-east-1:123456789012:stateless-rulegroup/hygiene", priority = 10, declared_capacity = 100, always_enforced = true }
      }
    }
  }
}

run "observation_uses_managed_override_and_customer_variant" {
  command = plan
  module { source = "./modules/policy-control" }
  assert {
    condition = (
      length([
        for reference in aws_networkfirewall_firewall_policy.this["release-2026-08-13-plain"].firewall_policy[0].stateful_rule_group_reference : reference
        if reference.resource_arn == "arn:aws:network-firewall:us-east-1:aws-managed:stateful-rulegroup/ThreatStrictOrder" && reference.priority == 100
      ]) == 1 &&
      length(one([
        for reference in aws_networkfirewall_firewall_policy.this["release-2026-08-13-plain"].firewall_policy[0].stateful_rule_group_reference : reference
        if reference.resource_arn == "arn:aws:network-firewall:us-east-1:aws-managed:stateful-rulegroup/ThreatStrictOrder" && reference.priority == 100
      ]).override) == 1 &&
      one(one([
        for reference in aws_networkfirewall_firewall_policy.this["release-2026-08-13-plain"].firewall_policy[0].stateful_rule_group_reference : reference
        if reference.resource_arn == "arn:aws:network-firewall:us-east-1:aws-managed:stateful-rulegroup/ThreatStrictOrder" && reference.priority == 100
      ]).override).action == "DROP_TO_ALERT" &&
      length([
        for reference in aws_networkfirewall_firewall_policy.this["release-2026-08-13-plain"].firewall_policy[0].stateful_rule_group_reference : reference
        if reference.resource_arn == "arn:aws:network-firewall:us-east-1:123456789012:stateful-rulegroup/customer-observe" && reference.priority == 200 && length(reference.override) == 0
      ]) == 1
    )
    error_message = "The rendered AWS policy must give exactly one managed reference DROP_TO_ALERT and swap the customer reference to observation_arn without overrides."
  }
}

run "selective_enforces_customer_wave" {
  command = plan
  module { source = "./modules/policy-control" }
  variables {
    policies = {
      release-2026-08-13-plain = {
        name = "inspection-release-2026-08-13-plain", enforcement = { mode = "selective" }, home_net_cidrs = ["10.0.0.0/8"]
        stateful_rule_groups = {
          managed  = { arn = "arn:aws:network-firewall:us-east-1:aws-managed:stateful-rulegroup/ManagedStrictOrder", priority = 100, kind = "managed", rule_order = "STRICT_ORDER", declared_capacity = 1000, enforce_from = "enforce", behavior = { actions = ["drop"], has_terminal_action = false, override_coverage = "all_blocking" } }
          customer = { arn = "arn:aws:network-firewall:us-east-1:123456789012:stateful-rulegroup/customer", observation_arn = "arn:aws:network-firewall:us-east-1:123456789012:stateful-rulegroup/customer-observe", priority = 200, kind = "customer", rule_order = "STRICT_ORDER", declared_capacity = 500, enforce_from = "selective", behavior = { actions = ["drop"], has_terminal_action = false, override_coverage = "all_blocking" } }
        }
      }
    }
  }
  assert {
    condition = (
      output.effective_releases["release-2026-08-13-plain"].stateful_rule_groups.managed.observed &&
      !output.effective_releases["release-2026-08-13-plain"].stateful_rule_groups.customer.observed
    )
    error_message = "Selective mode must enforce only groups whose enforce_from level has been reached."
  }
}

run "enforce_removes_all_observation_overrides" {
  command = plan
  module { source = "./modules/policy-control" }
  variables {
    policies = {
      release-2026-08-13-plain = {
        name                 = "inspection-release-2026-08-13-plain", enforcement = { mode = "enforce" }
        stateful_rule_groups = { managed = { arn = "arn:aws:network-firewall:us-east-1:aws-managed:stateful-rulegroup/ManagedStrictOrder", priority = 100, kind = "managed", rule_order = "STRICT_ORDER", declared_capacity = 1000, behavior = { actions = ["drop"], has_terminal_action = false, override_coverage = "all_blocking" } } }
      }
    }
  }
  assert {
    condition = (
      !output.effective_releases["release-2026-08-13-plain"].stateful_rule_groups.managed.observed &&
      contains(output.effective_releases["release-2026-08-13-plain"].stateful_default_actions, "aws:drop_strict")
    )
    error_message = "Enforce mode must remove observation overrides and activate strict default drop."
  }
}

run "incident_override_precedes_global_mode_and_rollout" {
  command = plan
  module { source = "./modules/policy-control" }
  variables {
    policies = {
      release-2026-08-13-plain = {
        name             = "inspection-release-2026-08-13-plain", enforcement = { mode = "enforce" }
        incident_control = { mode = "observe_all_stateful", group_overrides = { hotfix = "force_enforce" }, change_id = "INC-123", owner = "secops", expires_at = "2026-08-14T03:00:00Z" }
        stateful_rule_groups = {
          baseline = { arn = "arn:aws:network-firewall:us-east-1:aws-managed:stateful-rulegroup/BaselineStrictOrder", priority = 100, kind = "managed", rule_order = "STRICT_ORDER", declared_capacity = 100, behavior = { actions = ["drop"], has_terminal_action = false, override_coverage = "all_blocking" } }
          hotfix   = { arn = "arn:aws:network-firewall:us-east-1:123456789012:stateful-rulegroup/hotfix", priority = 200, kind = "customer", rule_order = "STRICT_ORDER", declared_capacity = 100, behavior = { actions = ["drop"], has_terminal_action = false, override_coverage = "all_blocking" } }
        }
      }
    }
  }
  assert {
    condition = (
      output.effective_releases["release-2026-08-13-plain"].stateful_rule_groups.baseline.observed &&
      !output.effective_releases["release-2026-08-13-plain"].stateful_rule_groups.hotfix.observed
    )
    error_message = "force_enforce must override observe_all_stateful, which must override enforce_from."
  }
}

run "render_home_net_and_engine_defaults" {
  command = plan
  module { source = "./modules/policy-control" }
  assert {
    condition = (
      one(one(aws_networkfirewall_firewall_policy.this["release-2026-08-13-plain"].firewall_policy[0].policy_variables).rule_variables).key == "HOME_NET" &&
      aws_networkfirewall_firewall_policy.this["release-2026-08-13-plain"].firewall_policy[0].stateful_engine_options[0].stream_exception_policy == "DROP" &&
      aws_networkfirewall_firewall_policy.this["release-2026-08-13-plain"].firewall_policy[0].stateful_engine_options[0].flow_timeouts[0].tcp_idle_timeout_seconds == 350
    )
    error_message = "Policy variables must contain only HOME_NET and engine defaults must be explicit."
  }
}

run "reject_blocking_customer_without_observation_variant" {
  command = plan
  module { source = "./modules/policy-control" }
  variables { policies = { bad-plain = { name = "bad-plain", stateful_rule_groups = { customer = { arn = "arn:aws:network-firewall:us-east-1:123456789012:stateful-rulegroup/customer", priority = 1, kind = "customer", rule_order = "STRICT_ORDER", declared_capacity = 10, behavior = { actions = ["drop"], has_terminal_action = false, override_coverage = "all_blocking" } } } } } }
  expect_failures = [terraform_data.policy_contract["bad-plain"]]
}

run "reject_incomplete_override_coverage" {
  command = plan
  module { source = "./modules/policy-control" }
  variables { policies = { bad-plain = { name = "bad-plain", stateful_rule_groups = { managed = { arn = "arn:aws:network-firewall:us-east-1:aws-managed:stateful-rulegroup/ManagedStrictOrder", priority = 1, kind = "managed", rule_order = "STRICT_ORDER", declared_capacity = 10, behavior = { actions = ["drop", "reject"], has_terminal_action = false, override_coverage = "drop_only" } } } } } }
  expect_failures = [terraform_data.policy_contract["bad-plain"]]
}

run "reject_behavior_terminal_mismatch" {
  command = plan
  module { source = "./modules/policy-control" }
  variables { policies = { bad-plain = { name = "bad-plain", enforcement = { mode = "enforce" }, stateful_rule_groups = { bad = { arn = "arn:aws:network-firewall:us-east-1:123456789012:stateful-rulegroup/bad", priority = 1, kind = "customer", rule_order = "STRICT_ORDER", declared_capacity = 10, behavior = { actions = ["pass"], has_terminal_action = false, override_coverage = "none" } } } } } }
  expect_failures = [terraform_data.policy_contract["bad-plain"]]
}

run "reject_required_home_net_missing" {
  command = plan
  module { source = "./modules/policy-control" }
  variables { policies = { bad-plain = { name = "bad-plain", enforcement = { mode = "enforce" }, stateful_rule_groups = { domains = { arn = "arn:aws:network-firewall:us-east-1:123456789012:stateful-rulegroup/domains", priority = 1, kind = "customer", rule_order = "STRICT_ORDER", declared_capacity = 10, requires_home_net = true, behavior = { actions = ["drop"], has_terminal_action = false, override_coverage = "all_blocking" } } } } } }
  expect_failures = [terraform_data.policy_contract["bad-plain"]]
}

run "reject_duplicate_stateful_priority" {
  command = plan
  module { source = "./modules/policy-control" }
  variables {
    policies = { bad-plain = { name = "bad-plain", enforcement = { mode = "enforce" }, stateful_rule_groups = {
      one = { arn = "arn:aws:network-firewall:us-east-1:123456789012:stateful-rulegroup/one", priority = 10, kind = "customer", rule_order = "STRICT_ORDER", declared_capacity = 10, behavior = { actions = ["alert"], has_terminal_action = false, override_coverage = "none" } }
      two = { arn = "arn:aws:network-firewall:us-east-1:123456789012:stateful-rulegroup/two", priority = 10, kind = "customer", rule_order = "STRICT_ORDER", declared_capacity = 10, behavior = { actions = ["alert"], has_terminal_action = false, override_coverage = "none" } }
    } } }
  }
  expect_failures = [terraform_data.policy_contract["bad-plain"]]
}

run "reject_stateful_capacity_total" {
  command = plan
  module { source = "./modules/policy-control" }
  variables {
    policies = { bad-plain = { name = "bad-plain", enforcement = { mode = "enforce" }, stateful_rule_groups = {
      one = { arn = "arn:aws:network-firewall:us-east-1:123456789012:stateful-rulegroup/one", priority = 1, kind = "customer", rule_order = "STRICT_ORDER", declared_capacity = 20000, behavior = { actions = ["alert"], has_terminal_action = false, override_coverage = "none" } }
      two = { arn = "arn:aws:network-firewall:us-east-1:123456789012:stateful-rulegroup/two", priority = 2, kind = "customer", rule_order = "STRICT_ORDER", declared_capacity = 20000, behavior = { actions = ["alert"], has_terminal_action = false, override_coverage = "none" } }
    } } }
  }
  expect_failures = [terraform_data.policy_contract["bad-plain"]]
}

run "reject_stateless_not_acknowledged" {
  command = plan
  module { source = "./modules/policy-control" }
  variables { policies = { bad-plain = { name = "bad-plain", stateless_rule_groups = { bad = { arn = "arn:aws:network-firewall:us-east-1:123456789012:stateful-rulegroup/bad", priority = 1, declared_capacity = 10, always_enforced = false } } } } }
  expect_failures = [terraform_data.policy_contract["bad-plain"]]
}

run "reject_stateful_reference_quota" {
  command = plan
  module { source = "./modules/policy-control" }
  variables {
    policies = { bad-plain = { name = "bad-plain", enforcement = { mode = "enforce" }, stateful_rule_groups = {
      for index in range(21) : "group-${index}" => { arn = format("arn:aws:network-firewall:us-east-1:123456789012:stateful-rulegroup/group-%d", index), priority = index + 1, kind = "customer", rule_order = "STRICT_ORDER", declared_capacity = 1, behavior = { actions = ["alert"], has_terminal_action = false, override_coverage = "none" } }
    } } }
  }
  expect_failures = [terraform_data.policy_contract["bad-plain"]]
}

run "reject_non_strict_reference" {
  command = plan
  module { source = "./modules/policy-control" }
  variables { policies = { bad-plain = { name = "bad-plain", enforcement = { mode = "enforce" }, stateful_rule_groups = { bad = { arn = "arn:aws:network-firewall:us-east-1:123456789012:stateful-rulegroup/bad", priority = 1, kind = "customer", rule_order = "DEFAULT_ACTION_ORDER", declared_capacity = 10, behavior = { actions = ["alert"], has_terminal_action = false, override_coverage = "none" } } } } } }
  expect_failures = [terraform_data.policy_contract["bad-plain"]]
}

run "reject_incident_without_metadata" {
  command = plan
  module { source = "./modules/policy-control" }
  variables { policies = { bad-plain = { name = "bad-plain", incident_control = { mode = "observe_all_stateful" } } } }
  expect_failures = [terraform_data.policy_contract["bad-plain"]]
}

run "reject_unknown_incident_slot" {
  command = plan
  module { source = "./modules/policy-control" }
  variables { policies = { bad-plain = { name = "bad-plain", incident_control = { group_overrides = { missing = "observe" }, change_id = "INC-1", owner = "secops", expires_at = "2026-08-14T03:00:00Z" } } } }
  expect_failures = [terraform_data.policy_contract["bad-plain"]]
}

run "reject_invalid_engine_options" {
  command = plan
  module { source = "./modules/policy-control" }
  variables { policies = { bad-plain = { name = "bad-plain", stream_exception_policy = "IGNORE", tcp_idle_timeout_seconds = 59 } } }
  expect_failures = [terraform_data.policy_contract["bad-plain"]]
}

run "reject_tls_presence_without_new_release_key" {
  command = plan
  module { source = "./modules/policy-control" }
  variables { policies = { bad-plain = { name = "bad-plain", tls = { inspection_configuration_arn = "arn:aws:network-firewall:us-east-1:123456789012:tls-configuration/tls-v1" } } } }
  expect_failures = [terraform_data.policy_contract["bad-plain"]]
}

run "create_tls_release_with_customer_kms" {
  command = plan
  module { source = "./modules/policy-control" }
  variables {
    policies = { candidate-2026-08-13-tls = {
      name       = "inspection-candidate-2026-08-13-tls"
      tls        = { inspection_configuration_arn = "arn:aws:network-firewall:us-east-1:123456789012:tls-configuration/tls-v1" }
      encryption = { type = "CUSTOMER_KMS", key_arn = "arn:aws:kms:us-east-1:123456789012:key/abc" }
    } }
  }
  assert {
    condition     = one(aws_networkfirewall_firewall_policy.this["candidate-2026-08-13-tls"].encryption_configuration).type == "CUSTOMER_KMS"
    error_message = "TLS release with customer KMS must render explicit encryption."
  }
}

run "inject_policy_release" {
  command = plan
  module { source = "./modules/policy-control" }
  variables { policies = { existing-plain = { create = false, arn = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/existing", metadata = { rule_order = "STRICT_ORDER", tls_enabled = false } } } }
  assert {
    condition     = length(aws_networkfirewall_firewall_policy.this) == 0 && output.policy_arns.existing-plain == "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/existing"
    error_message = "Injected policy releases must create nothing and return their ARN."
  }
}


run "typed_records_propagate_home_net" {
  command = plan
  module { source = "./modules/policy-control" }
  variables {
    rule_group_records = {
      domains = {
        arn                = "arn:aws:network-firewall:us-east-1:123456789012:stateful-rulegroup/domains"
        type               = "STATEFUL"
        rule_order         = "STRICT_ORDER"
        declared_capacity  = 10
        kind               = "customer"
        content_management = "terraform"
        requires_home_net  = true
        validation_mode    = "aws_apply"
      }
    }
    policies = {
      typed-plain = {
        name = "typed-plain", enforcement = { mode = "enforce" }, home_net_cidrs = ["10.0.0.0/8"]
        stateful_rule_groups = {
          domains = {
            arn      = "arn:aws:network-firewall:us-east-1:123456789012:stateful-rulegroup/domains", priority = 1, kind = "customer", rule_order = "STRICT_ORDER", declared_capacity = 10
            behavior = { actions = ["alert"], has_terminal_action = false, override_coverage = "none" }
          }
        }
      }
    }
  }
  assert {
    condition     = output.effective_releases.typed-plain.stateful_rule_groups.domains.requires_home_net
    error_message = "Matching rule_group_records must propagate requires_home_net when the policy slot omits it."
  }
}

run "typed_records_require_home_net_without_manual_copy" {
  command = plan
  module { source = "./modules/policy-control" }
  variables {
    rule_group_records = {
      domains = {
        arn                = "arn:aws:network-firewall:us-east-1:123456789012:stateful-rulegroup/domains", type = "STATEFUL", rule_order = "STRICT_ORDER", declared_capacity = 10, kind = "customer"
        content_management = "terraform", requires_home_net = true, validation_mode = "aws_apply"
      }
    }
    policies = {
      bad-plain = {
        name = "bad-plain", enforcement = { mode = "enforce" }
        stateful_rule_groups = {
          domains = {
            arn      = "arn:aws:network-firewall:us-east-1:123456789012:stateful-rulegroup/domains", priority = 1, kind = "customer", rule_order = "STRICT_ORDER", declared_capacity = 10
            behavior = { actions = ["alert"], has_terminal_action = false, override_coverage = "none" }
          }
        }
      }
    }
  }
  expect_failures = [terraform_data.policy_contract["bad-plain"]]
}

run "typed_records_reject_incoherent_reference" {
  command = plan
  module { source = "./modules/policy-control" }
  variables {
    rule_group_records = {
      domains = {
        arn                = "arn:aws:network-firewall:us-east-1:123456789012:stateful-rulegroup/domains", type = "STATEFUL", rule_order = "STRICT_ORDER", declared_capacity = 10, kind = "customer"
        content_management = "terraform", requires_home_net = false, validation_mode = "aws_apply"
      }
    }
    policies = {
      bad-plain = {
        name = "bad-plain", enforcement = { mode = "enforce" }
        stateful_rule_groups = {
          domains = {
            arn      = "arn:aws:network-firewall:us-east-1:123456789012:stateful-rulegroup/domains", priority = 1, kind = "customer", rule_order = "STRICT_ORDER", declared_capacity = 11
            behavior = { actions = ["alert"], has_terminal_action = false, override_coverage = "none" }
          }
        }
      }
    }
  }
  expect_failures = [terraform_data.policy_contract["bad-plain"]]
}
