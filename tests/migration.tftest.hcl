mock_provider "aws" {
  mock_resource "aws_networkfirewall_firewall" {
    defaults = {
      id   = "firewall-stateful-id"
      arn  = "arn:aws:network-firewall:us-east-1:123456789012:firewall/stateful"
      name = "stateful"
      firewall_status = [{
        sync_states = [{
          availability_zone = "us-east-1a"
          attachment = [{
            endpoint_id = "vpce-0123456789abcdef0"
            subnet_id   = "subnet-0123456789abcdef0"
          }]
        }]
        transit_gateway_attachment_sync_states = []
      }]
    }
  }

  mock_resource "aws_networkfirewall_logging_configuration" {
    defaults = { id = "logging-stateful-id" }
  }

  mock_resource "aws_route" {
    defaults = { id = "route-stateful-id" }
  }
}

run "apply_v1_addresses" {
  command   = apply
  state_key = "v1-to-v2-state"

  module { source = "./tests/fixtures/moved-v1" }

  assert {
    condition = (
      output.firewall_id == "firewall-stateful-id" &&
      output.logging_id == "logging-stateful-id" &&
      output.route_id == "route-stateful-id"
    )
    error_message = "The v1 fixture must seed firewall, logging count[0], and positional route state."
  }
}

run "plan_v2_addresses" {
  command   = plan
  state_key = "v1-to-v2-state"

  module { source = "./tests/fixtures/moved-v2" }

  assert {
    condition     = output.firewall_id == run.apply_v1_addresses.firewall_id
    error_message = "The firewall ID must survive anfw to this[primary] without replacement."
  }

  assert {
    condition     = output.logging_id == run.apply_v1_addresses.logging_id
    error_message = "The logging ID must survive count[0] to the primary key without replacement."
  }

  assert {
    condition     = output.route_id == run.apply_v1_addresses.route_id
    error_message = "The route ID must survive its positional-to-semantic key move without replacement."
  }
}
