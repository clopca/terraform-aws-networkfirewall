mock_provider "aws" {
  mock_resource "aws_networkfirewall_firewall" {
    defaults = {
      id   = "firewall-family-id"
      arn  = "arn:aws:network-firewall:us-east-1:123456789012:firewall/family"
      name = "family"
      firewall_status = [{
        status                           = "READY"
        configuration_sync_state_summary = "IN_SYNC"
        sync_states = [{
          availability_zone = "us-east-1a"
          attachment = [{
            endpoint_id = "vpce-0123456789abcdef0"
            subnet_id   = "subnet-0123456789abcdef0"
            status      = "READY"
          }]
        }]
        transit_gateway_attachment_sync_states = []
      }]
    }
  }
}

run "apply_ipv4_mapping" {
  command   = apply
  state_key = "address-family-transition"

  variables {
    firewalls = {
      primary = {
        name       = "family"
        policy_arn = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/family"
        placement = { vpc = {
          vpc_id = "vpc-0123456789abcdef0"
          endpoint_subnets = {
            "us-east-1a" = { subnet_id = "subnet-0123456789abcdef0", ip_address_type = "IPV4" }
          }
        } }
      }
    }
  }
}

run "reject_same_key_ipv4_to_dualstack_without_ack" {
  command   = plan
  state_key = "address-family-transition"

  variables {
    firewalls = {
      primary = {
        name       = "family"
        policy_arn = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/family"
        placement = { vpc = {
          vpc_id = "vpc-0123456789abcdef0"
          endpoint_subnets = {
            "us-east-1a" = { subnet_id = "subnet-0123456789abcdef0", ip_address_type = "DUALSTACK" }
          }
        } }
      }
    }
  }

  expect_failures = [terraform_data.firewall_contract["primary"]]
}

run "accept_same_key_ipv4_to_dualstack_with_explicit_ack" {
  command   = plan
  state_key = "address-family-transition"

  variables {
    firewalls = {
      primary = {
        name       = "family"
        policy_arn = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/family"
        placement = { vpc = {
          vpc_id = "vpc-0123456789abcdef0"
          endpoint_subnets = {
            "us-east-1a" = {
              subnet_id                    = "subnet-0123456789abcdef0"
              ip_address_type              = "DUALSTACK"
              address_family_migration_ack = true
            }
          }
        } }
      }
    }
  }

  assert {
    condition     = one(aws_networkfirewall_firewall.this["primary"].subnet_mapping).ip_address_type == "DUALSTACK"
    error_message = "A literal true acknowledgement must permit the reviewed DUALSTACK mapping plan."
  }
}

# Terraform defers variable preconditions whose conditions are unknown. This plan
# intentionally passes to lock in the documented limitation: an unknown bool cannot
# be rejected during plan, so callers should supply a literal true and let apply be
# the final authority for any computed acknowledgement.
run "document_unknown_ack_defers_to_apply" {
  command = plan
  module { source = "./tests/fixtures/address-family-unknown" }
}
