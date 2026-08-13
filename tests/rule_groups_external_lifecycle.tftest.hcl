mock_provider "aws" {
  mock_resource "aws_networkfirewall_rule_group" {
    defaults = {
      arn          = "arn:aws:network-firewall:us-east-1:123456789012:stateful-rulegroup/soc-v1"
      id           = "soc-v1"
      update_token = "token"
    }
  }
}

run "apply_external_seed" {
  command = apply
  module { source = "./modules/rule-groups" }
  variables {
    rule_groups = {
      soc = {
        name   = "soc-v1", type = "STATEFUL", capacity = 1000, content_management = "external"
        source = { rules_string = "alert ip any any -> any any (msg:\"bootstrap\"; sid:9001;)" }
      }
    }
  }
}

run "external_content_change_has_no_diff" {
  command = plan
  module { source = "./modules/rule-groups" }
  variables {
    rule_groups = {
      soc = {
        name   = "soc-v1", type = "STATEFUL", capacity = 1000, content_management = "external"
        source = { rules_string = "drop ip any any -> any any (msg:\"SOC live update\"; sid:9002;)" }
      }
    }
  }
  assert {
    condition     = aws_networkfirewall_rule_group.external_content["soc"].rule_group[0].rules_source[0].rules_string == "alert ip any any -> any any (msg:\"bootstrap\"; sid:9001;)"
    error_message = "External content changes must be ignored after bootstrap so Terraform does not fight UpdateRuleGroup."
  }
}

run "reject_external_with_attestation" {
  command = plan
  module { source = "./modules/rule-groups" }
  variables {
    rule_groups = {
      bad = {
        name              = "bad", type = "STATEFUL", capacity = 10, content_management = "external"
        source            = { rules_string = "alert ip any any -> any any (sid:1;)" }
        source_validation = { mode = "attested", manifest_uri = "s3://evidence/bad.json", bundle_sha256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" }
      }
    }
  }
  expect_failures = [terraform_data.rule_group_contract["bad"]]
}
