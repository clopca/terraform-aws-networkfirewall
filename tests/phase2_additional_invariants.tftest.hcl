mock_provider "aws" {
  override_during = plan
  mock_resource "aws_networkfirewall_rule_group" {
    defaults = { arn = "arn:aws:network-firewall:us-east-1:123456789012:stateful-rulegroup/mock", id = "mock", update_token = "token" }
  }
  mock_resource "aws_networkfirewall_firewall_policy" {
    defaults = { arn = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/mock", id = "mock", update_token = "token" }
  }
}

run "rule_group_rejects_missing_source" {
  command = plan
  module { source = "./modules/rule-groups" }
  variables { rule_groups = { bad = { name = "bad", type = "STATEFUL", capacity = 10, source_validation = { mode = "aws_apply" } } } }
  expect_failures = [terraform_data.rule_group_contract["bad"]]
}

run "rule_group_rejects_missing_source_validation" {
  command = plan
  module { source = "./modules/rule-groups" }
  variables { rule_groups = { bad = { name = "bad", type = "STATEFUL", capacity = 10, source = { rules_string = "alert ip any any -> any any (sid:1;)" } } } }
  expect_failures = [terraform_data.rule_group_contract["bad"]]
}

run "rule_group_rejects_invalid_domain_list" {
  command = plan
  module { source = "./modules/rule-groups" }
  variables { rule_groups = { bad = { name = "bad", type = "STATEFUL", capacity = 10, source = { rules_source_list = { generated_rules_type = "MAYBELIST", target_types = ["IP"], targets = [] } }, source_validation = { mode = "aws_apply" } } } }
  expect_failures = [terraform_data.rule_group_contract["bad"]]
}

run "rule_group_rejects_invalid_encryption" {
  command = plan
  module { source = "./modules/rule-groups" }
  variables { rule_groups = { bad = { name = "bad", type = "STATEFUL", capacity = 10, source = { rules_string = "alert ip any any -> any any (sid:1;)" }, source_validation = { mode = "aws_apply" }, encryption = { type = "CUSTOMER_KMS" } } } }
  expect_failures = [terraform_data.rule_group_contract["bad"]]
}

run "rule_group_rejects_inject_without_metadata" {
  command = plan
  module { source = "./modules/rule-groups" }
  variables { rule_groups = { bad = { create = false, arn = "arn:aws:network-firewall:us-east-1:123456789012:stateful-rulegroup/existing" } } }
  expect_failures = [terraform_data.rule_group_contract["bad"]]
}

run "policy_rejects_stateless_reference_quota" {
  command = plan
  module { source = "./modules/policy-control" }
  variables {
    policies = { bad-plain = { name = "bad-plain", stateless_rule_groups = {
      for index in range(21) : "group-${index}" => { arn = format("arn:aws:network-firewall:us-east-1:123456789012:stateless-rulegroup/group-%d", index), priority = index + 1, declared_capacity = 1, always_enforced = true }
    } } }
  }
  expect_failures = [terraform_data.policy_contract["bad-plain"]]
}

run "policy_rejects_duplicate_stateless_priority" {
  command = plan
  module { source = "./modules/policy-control" }
  variables {
    policies = { bad-plain = { name = "bad-plain", stateless_rule_groups = {
      one = { arn = "arn:aws:network-firewall:us-east-1:123456789012:stateless-rulegroup/one", priority = 10, declared_capacity = 1, always_enforced = true }
      two = { arn = "arn:aws:network-firewall:us-east-1:123456789012:stateless-rulegroup/two", priority = 10, declared_capacity = 1, always_enforced = true }
    } } }
  }
  expect_failures = [terraform_data.policy_contract["bad-plain"]]
}

run "policy_rejects_stateless_capacity_total" {
  command = plan
  module { source = "./modules/policy-control" }
  variables {
    policies = { bad-plain = { name = "bad-plain", stateless_rule_groups = {
      one = { arn = "arn:aws:network-firewall:us-east-1:123456789012:stateless-rulegroup/one", priority = 1, declared_capacity = 20000, always_enforced = true }
      two = { arn = "arn:aws:network-firewall:us-east-1:123456789012:stateless-rulegroup/two", priority = 2, declared_capacity = 20000, always_enforced = true }
    } } }
  }
  expect_failures = [terraform_data.policy_contract["bad-plain"]]
}

run "policy_rejects_priority_outside_range" {
  command = plan
  module { source = "./modules/policy-control" }
  variables {
    policies = { bad-plain = { name = "bad-plain", enforcement = { mode = "enforce" }, stateful_rule_groups = {
      bad = { arn = "arn:aws:network-firewall:us-east-1:123456789012:stateful-rulegroup/bad", priority = 65536, kind = "customer", rule_order = "STRICT_ORDER", declared_capacity = 1, behavior = { actions = ["alert"], has_terminal_action = false, override_coverage = "none" } }
    } } }
  }
  expect_failures = [terraform_data.policy_contract["bad-plain"]]
}

run "policy_rejects_invalid_encryption" {
  command = plan
  module { source = "./modules/policy-control" }
  variables { policies = { bad-plain = { name = "bad-plain", encryption = { type = "AWS_OWNED_KMS_KEY", key_arn = "arn:aws:kms:us-east-1:123456789012:key/abc" } } } }
  expect_failures = [terraform_data.policy_contract["bad-plain"]]
}

run "policy_rejects_name_without_release_key" {
  command = plan
  module { source = "./modules/policy-control" }
  variables { policies = { release-2026-08-13-plain = { name = "inspection" } } }
  expect_failures = [terraform_data.policy_contract["release-2026-08-13-plain"]]
}

run "policy_rejects_injected_tls_metadata_mismatch" {
  command = plan
  module { source = "./modules/policy-control" }
  variables { policies = { existing-plain = { create = false, arn = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/existing", metadata = { rule_order = "STRICT_ORDER", tls_enabled = true } } } }
  expect_failures = [terraform_data.policy_contract["existing-plain"]]
}
