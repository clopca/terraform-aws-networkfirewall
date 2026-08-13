mock_provider "aws" {
  mock_resource "aws_networkfirewall_firewall" {
    defaults = {
      id   = "central-firewall-id"
      arn  = "arn:aws:network-firewall:us-east-1:123456789012:firewall/central-migration"
      name = "central-migration"
      firewall_status = [{
        status                           = "READY"
        configuration_sync_state_summary = "IN_SYNC"
        sync_states = [
          { availability_zone = "us-east-1a", attachment = [{ endpoint_id = "vpce-aaaaaaaaaaaaaaaaa", subnet_id = "subnet-aaaaaaaaaaaaaaaaa", status = "READY" }] },
          { availability_zone = "us-east-1b", attachment = [{ endpoint_id = "vpce-bbbbbbbbbbbbbbbbb", subnet_id = "subnet-bbbbbbbbbbbbbbbbb", status = "READY" }] },
        ]
        transit_gateway_attachment_sync_states = []
      }]
    }
  }
  mock_resource "aws_networkfirewall_logging_configuration" {
    defaults = { id = "central-logging-id" }
  }
  mock_resource "aws_route" {
    defaults = { id = "unmoved-route-id" }
  }
}

run "apply_v1_central_inspection_with_egress" {
  command   = apply
  state_key = "central-v1-to-v2"
  module { source = "./tests/fixtures/central-v1" }

  override_resource {
    target = module.nfw.aws_route.connectivity_to_firewall_endpoint[0]
    values = { id = "connectivity-a-id" }
  }
  override_resource {
    target = module.nfw.aws_route.connectivity_to_firewall_endpoint[1]
    values = { id = "connectivity-b-id" }
  }
  override_resource {
    target = module.nfw.module.central_inspection_with_egress_routing[0].aws_route.route_public_to_firewall_endpoint[0]
    values = { id = "public-a-spoke-0-id" }
  }
  override_resource {
    target = module.nfw.module.central_inspection_with_egress_routing[0].aws_route.route_public_to_firewall_endpoint[1]
    values = { id = "public-a-spoke-1-id" }
  }
  override_resource {
    target = module.nfw.module.central_inspection_with_egress_routing[1].aws_route.route_public_to_firewall_endpoint[0]
    values = { id = "public-b-spoke-0-id" }
  }
  override_resource {
    target = module.nfw.module.central_inspection_with_egress_routing[1].aws_route.route_public_to_firewall_endpoint[1]
    values = { id = "public-b-spoke-1-id" }
  }

  assert {
    condition = (
      output.firewall.id == "central-firewall-id" &&
      output.logging_id == "central-logging-id" &&
      length(output.connectivity_route_ids) == 2 &&
      length(output.central_route_ids) == 4
    )
    error_message = "The v1 fixture must seed firewall, CloudWatch logging, two connectivity routes, and four AZ×CIDR routes."
  }
}

run "plan_complete_v2_central_inspection_with_egress" {
  command   = plan
  state_key = "central-v1-to-v2"
  module { source = "./tests/fixtures/central-v2" }

  assert {
    condition     = output.firewall.id == run.apply_v1_central_inspection_with_egress.firewall.id
    error_message = "The product root moved block must preserve the central firewall ID."
  }

  assert {
    condition = (
      output.firewall.description == run.apply_v1_central_inspection_with_egress.firewall.description &&
      output.firewall.policy_arn == run.apply_v1_central_inspection_with_egress.firewall.policy_arn &&
      output.firewall.delete_protection == run.apply_v1_central_inspection_with_egress.firewall.delete_protection &&
      output.firewall.policy_change_protection == run.apply_v1_central_inspection_with_egress.firewall.policy_change_protection &&
      output.firewall.subnet_change_protection == run.apply_v1_central_inspection_with_egress.firewall.subnet_change_protection &&
      output.firewall.availability_zone_change_protection == run.apply_v1_central_inspection_with_egress.firewall.availability_zone_change_protection &&
      output.firewall.encryption_key == run.apply_v1_central_inspection_with_egress.firewall.encryption_key &&
      output.firewall.tags == run.apply_v1_central_inspection_with_egress.firewall.tags &&
      output.firewall.subnet_ids == run.apply_v1_central_inspection_with_egress.firewall.subnet_ids
    )
    error_message = "Description, policy, four protections, customer KMS, effective tags, and both endpoint subnets must remain identical."
  }

  assert {
    condition = (
      output.logging_id == run.apply_v1_central_inspection_with_egress.logging_id &&
      output.cloudwatch_log_group_count == 0
    )
    error_message = "CloudWatch logging must move while the existing log group remains inject-only (create=false)."
  }

  assert {
    condition = alltrue([
      for key, id in run.apply_v1_central_inspection_with_egress.connectivity_route_ids :
      output.connectivity_route_ids[key] == id
    ])
    error_message = "Both per-AZ connectivity route IDs must survive their explicit moves."
  }

  assert {
    condition = alltrue([
      for key, id in run.apply_v1_central_inspection_with_egress.central_route_ids :
      output.central_route_ids[key] == id
    ])
    error_message = "All four AZ×CIDR central route IDs must survive their explicit moves."
  }
}
