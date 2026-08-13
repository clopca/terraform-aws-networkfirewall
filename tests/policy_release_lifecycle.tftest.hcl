mock_provider "aws" {
  mock_resource "aws_networkfirewall_firewall_policy" {
    defaults = {
      arn          = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/mock"
      id           = "mock"
      update_token = "token"
    }
  }
}

run "apply_active_and_last_known_good_releases" {
  command = apply
  module { source = "./modules/policy-control" }
  variables {
    policies = {
      active-2026-08-12-plain          = { name = "inspection-active-2026-08-12-plain", enforcement = { mode = "enforce" } }
      last-known-good-2026-08-11-plain = { name = "inspection-last-known-good-2026-08-11-plain", enforcement = { mode = "enforce" } }
    }
  }
}

run "add_tls_candidate_preserves_rollback_releases" {
  command = plan
  module { source = "./modules/policy-control" }
  variables {
    policies = {
      active-2026-08-12-plain          = { name = "inspection-active-2026-08-12-plain", enforcement = { mode = "enforce" } }
      last-known-good-2026-08-11-plain = { name = "inspection-last-known-good-2026-08-11-plain", enforcement = { mode = "enforce" } }
      candidate-2026-08-13-tls = {
        name = "inspection-candidate-2026-08-13-tls"
        tls  = { inspection_configuration_arn = "arn:aws:network-firewall:us-east-1:123456789012:tls-configuration/candidate" }
      }
    }
  }
  assert {
    condition = toset(keys(aws_networkfirewall_firewall_policy.this)) == toset([
      "active-2026-08-12-plain",
      "last-known-good-2026-08-11-plain",
      "candidate-2026-08-13-tls",
    ])
    error_message = "Adding a TLS candidate must retain active and last-known-good release addresses."
  }
}
