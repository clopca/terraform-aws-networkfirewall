mock_provider "aws" {
  override_during = plan

  mock_data "aws_networkfirewall_firewall" {
    defaults = {
      id                  = "injected-firewall-id"
      arn                 = "arn:aws:network-firewall:us-east-1:123456789012:firewall/injected"
      name                = "injected"
      firewall_policy_arn = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/injected"
      firewall_status = [{
        status                           = "READY"
        configuration_sync_state_summary = "IN_SYNC"
        capacity_usage_summary           = []
        sync_states = [{
          availability_zone = "us-east-1a"
          attachment = [{
            endpoint_id = "vpce-aaaaaaaaaaaaaaaaa"
            status      = "READY"
            subnet_id   = "subnet-aaaaaaaaaaaaaaaaa"
          }]
        }]
        transit_gateway_attachment_sync_states = []
      }]
    }
  }
}

variables {
  firewalls = {
    external = {
      create = false
      arn    = "arn:aws:network-firewall:us-east-1:123456789012:firewall/injected"
      placement = { vpc = {
        vpc_id = "vpc-0123456789abcdef0"
        endpoint_subnets = {
          "us-east-1a" = { subnet_id = "subnet-aaaaaaaaaaaaaaaaa", availability_zone_id = "use1-az1" }
        }
      } }
    }
  }
}

run "global_provisioning_is_unverified" {
  command = apply

  override_data {
    target = data.aws_networkfirewall_firewall.this["external"]
    values = {
      firewall_status = [{
        status                           = "PROVISIONING"
        configuration_sync_state_summary = "IN_SYNC"
        capacity_usage_summary           = []
        sync_states = [{
          availability_zone = "us-east-1a"
          attachment        = [{ endpoint_id = "vpce-aaaaaaaaaaaaaaaaa", status = "READY", subnet_id = "subnet-aaaaaaaaaaaaaaaaa" }]
        }]
        transit_gateway_attachment_sync_states = []
      }]
    }
  }

  assert {
    condition     = output.vpc_endpoint_records_by_firewall_by_az.external["us-east-1a"].readiness_guarantee == "unverified"
    error_message = "A PROVISIONING firewall must never publish observed_ready."
  }
}

run "out_of_sync_is_unverified" {
  command = apply

  override_data {
    target = data.aws_networkfirewall_firewall.this["external"]
    values = {
      firewall_status = [{
        status                           = "READY"
        configuration_sync_state_summary = "OUT_OF_SYNC"
        capacity_usage_summary           = []
        sync_states = [{
          availability_zone = "us-east-1a"
          attachment        = [{ endpoint_id = "vpce-aaaaaaaaaaaaaaaaa", status = "READY", subnet_id = "subnet-aaaaaaaaaaaaaaaaa" }]
        }]
        transit_gateway_attachment_sync_states = []
      }]
    }
  }

  assert {
    condition     = output.vpc_endpoint_records_by_firewall_by_az.external["us-east-1a"].readiness_guarantee == "unverified"
    error_message = "An OUT_OF_SYNC firewall must never publish observed_ready."
  }
}

run "mixed_attachment_readiness_is_unverified_for_all_requested_azs" {
  command = apply

  variables {
    firewalls = {
      external = {
        create = false
        arn    = "arn:aws:network-firewall:us-east-1:123456789012:firewall/injected"
        placement = { vpc = {
          vpc_id = "vpc-0123456789abcdef0"
          endpoint_subnets = {
            "us-east-1a" = { subnet_id = "subnet-aaaaaaaaaaaaaaaaa", availability_zone_id = "use1-az1" }
            "us-east-1b" = { subnet_id = "subnet-bbbbbbbbbbbbbbbbb", availability_zone_id = "use1-az2" }
          }
        } }
      }
    }
  }

  override_data {
    target = data.aws_networkfirewall_firewall.this["external"]
    values = {
      firewall_status = [{
        status                           = "READY"
        configuration_sync_state_summary = "IN_SYNC"
        capacity_usage_summary           = []
        sync_states = [
          {
            availability_zone = "us-east-1a"
            attachment        = [{ endpoint_id = "vpce-aaaaaaaaaaaaaaaaa", status = "READY", subnet_id = "subnet-aaaaaaaaaaaaaaaaa" }]
          },
          {
            availability_zone = "us-east-1b"
            attachment        = [{ endpoint_id = "vpce-bbbbbbbbbbbbbbbbb", status = "PROVISIONING", subnet_id = "subnet-bbbbbbbbbbbbbbbbb" }]
          },
        ]
        transit_gateway_attachment_sync_states = []
      }]
    }
  }

  assert {
    condition = alltrue([
      for record in values(output.vpc_endpoint_records_by_firewall_by_az.external) :
      record.readiness_guarantee == "unverified"
    ])
    error_message = "Every requested attachment must be READY before any injected endpoint record is observed_ready."
  }
}
