mock_provider "aws" {
  mock_resource "aws_networkfirewall_firewall" {
    defaults = {
      id   = "product-moved-firewall-id"
      arn  = "arn:aws:network-firewall:us-east-1:123456789012:firewall/product-moved"
      name = "product-moved"
      firewall_status = [{
        status                           = "READY"
        configuration_sync_state_summary = "IN_SYNC"
        sync_states = [{
          availability_zone = "us-east-1a"
          attachment        = [{ endpoint_id = "vpce-0123456789abcdef0", subnet_id = "subnet-0123456789abcdef0", status = "READY" }]
        }]
        transit_gateway_attachment_sync_states = []
      }]
    }
  }
}

run "apply_legacy_product_address" {
  command   = apply
  state_key = "product-root-move"
  module { source = "./tests/fixtures/product-moved-v1" }

  assert {
    condition     = output.firewall_id == "product-moved-firewall-id"
    error_message = "The legacy fixture must seed the singleton firewall address."
  }
}

run "plan_actual_root_product_address" {
  command   = plan
  state_key = "product-root-move"

  variables {
    firewalls = {
      primary = {
        name       = "product-moved"
        policy_arn = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/product-moved"
        placement = { vpc = {
          vpc_id = "vpc-0123456789abcdef0"
          endpoint_subnets = {
            "us-east-1a" = { subnet_id = "subnet-0123456789abcdef0" }
          }
        } }
        protections = { delete = false, policy_change = false, subnet_change = false, availability_zone_change = false }
      }
    }
  }

  assert {
    condition     = output.firewall_ids.primary == run.apply_legacy_product_address.firewall_id
    error_message = "The firewall ID must survive through the product root moved block; a fixture copy does not satisfy this test."
  }
}
