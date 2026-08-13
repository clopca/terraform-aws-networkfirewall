mock_provider "aws" {
  override_during = plan

  mock_resource "aws_networkfirewall_firewall" {
    defaults = {
      id   = "firewall-mock-id"
      arn  = "arn:aws:network-firewall:us-east-1:123456789012:firewall/mock"
      name = "mock"
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

  mock_data "aws_networkfirewall_firewall" {
    defaults = {
      id   = "injected-firewall-id"
      arn  = "arn:aws:network-firewall:us-east-1:123456789012:firewall/injected"
      name = "injected"
      firewall_status = [{
        status                           = "READY"
        configuration_sync_state_summary = "IN_SYNC"
        capacity_usage_summary           = []
        sync_states = [{
          availability_zone = "us-east-1a"
          attachment = [{
            endpoint_id    = "vpce-0223456789abcdef0"
            status         = "READY"
            status_message = ""
            subnet_id      = "subnet-0223456789abcdef0"
          }]
        }]
        transit_gateway_attachment_sync_states = []
      }]
    }
  }
}

run "create_dual_stack_firewall" {
  command = plan

  variables {
    firewalls = {
      primary = {
        name       = "inspection"
        policy_arn = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/inspection"
        placement = {
          vpc = {
            vpc_id = "vpc-0123456789abcdef0"
            endpoint_subnets = {
              "us-east-1a" = {
                subnet_id       = "subnet-0123456789abcdef0"
                ip_address_type = "DUALSTACK"
              }
            }
          }
        }
      }
    }
  }

  assert {
    condition = (
      output.firewall_ids.primary == "firewall-mock-id" &&
      output.firewall_names.primary == "inspection" &&
      output.endpoint_ids_by_firewall_by_zone.primary["us-east-1a"] == "vpce-0123456789abcdef0"
    )
    error_message = "Created firewalls must expose stable handles and input-derived zone keys."
  }

  assert {
    condition = (
      aws_networkfirewall_firewall.this["primary"].delete_protection &&
      aws_networkfirewall_firewall.this["primary"].firewall_policy_change_protection &&
      aws_networkfirewall_firewall.this["primary"].subnet_change_protection &&
      aws_networkfirewall_firewall.this["primary"].availability_zone_change_protection
    )
    error_message = "All create-mode protections must default to true."
  }
}

run "inject_firewall_by_arn" {
  command = apply

  variables {
    firewalls = {
      external = {
        create = false
        arn    = "arn:aws:network-firewall:us-east-1:123456789012:firewall/injected"
      }
    }
  }

  assert {
    condition = (
      length(aws_networkfirewall_firewall.this) == 0 &&
      output.firewall_arns.external == "arn:aws:network-firewall:us-east-1:123456789012:firewall/injected" &&
      output.firewall_ids.external == "injected-firewall-id" &&
      output.endpoint_ids_by_firewall_by_zone.external == {}
    )
    error_message = "Inject mode must read the firewall by ARN without taking lifecycle ownership."
  }
}

run "reject_injected_firewall_without_arn" {
  command = plan
  variables { firewalls = { bad = { create = false } } }
  expect_failures = [terraform_data.firewall_contract["bad"]]
}

run "reject_create_with_arn" {
  command = plan
  variables {
    firewalls = {
      bad = {
        arn        = "arn:aws:network-firewall:us-east-1:123456789012:firewall/existing"
        name       = "bad"
        policy_arn = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/policy"
        placement  = { vpc = { vpc_id = "vpc-1", endpoint_subnets = { a = { subnet_id = "subnet-1" } } } }
      }
    }
  }
  expect_failures = [terraform_data.firewall_contract["bad"]]
}

run "reject_missing_create_fields" {
  command = plan
  variables { firewalls = { bad = {} } }
  expect_failures = [terraform_data.firewall_contract["bad"]]
}

run "reject_reserved_transit_gateway_placement" {
  command = plan
  variables {
    firewalls = {
      bad = {
        name       = "bad"
        policy_arn = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/policy"
        placement = {
          transit_gateway = {
            transit_gateway_id = "tgw-0123456789abcdef0"
            availability_zones = { zone1 = { availability_zone_id = "use1-az1" } }
          }
        }
      }
    }
  }
  expect_failures = [terraform_data.firewall_contract["bad"]]
}

run "reject_empty_endpoint_subnets" {
  command = plan
  variables {
    firewalls = {
      bad = {
        name       = "bad"
        policy_arn = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/policy"
        placement  = { vpc = { vpc_id = "vpc-1", endpoint_subnets = {} } }
      }
    }
  }
  expect_failures = [terraform_data.firewall_contract["bad"]]
}

run "reject_duplicate_endpoint_subnets" {
  command = plan
  variables {
    firewalls = {
      bad = {
        name       = "bad"
        policy_arn = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/policy"
        placement = {
          vpc = {
            vpc_id = "vpc-1"
            endpoint_subnets = {
              a = { subnet_id = "subnet-1" }
              b = { subnet_id = "subnet-1" }
            }
          }
        }
      }
    }
  }
  expect_failures = [terraform_data.firewall_contract["bad"]]
}

run "reject_invalid_ip_address_type" {
  command = plan
  variables {
    firewalls = {
      bad = {
        name       = "bad"
        policy_arn = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/policy"
        placement  = { vpc = { vpc_id = "vpc-1", endpoint_subnets = { a = { subnet_id = "subnet-1", ip_address_type = "IPV5" } } } }
      }
    }
  }
  expect_failures = [terraform_data.firewall_contract["bad"]]
}

run "reject_customer_kms_without_key" {
  command = plan
  variables {
    firewalls = {
      bad = {
        name       = "bad"
        policy_arn = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/policy"
        placement  = { vpc = { vpc_id = "vpc-1", endpoint_subnets = { a = { subnet_id = "subnet-1" } } } }
        encryption = { type = "CUSTOMER_KMS" }
      }
    }
  }
  expect_failures = [terraform_data.firewall_contract["bad"]]
}

run "reject_aws_owned_kms_with_key" {
  command = plan
  variables {
    firewalls = {
      bad = {
        name       = "bad"
        policy_arn = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/policy"
        placement  = { vpc = { vpc_id = "vpc-1", endpoint_subnets = { a = { subnet_id = "subnet-1" } } } }
        encryption = {
          type    = "AWS_OWNED_KMS_KEY"
          key_arn = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
        }
      }
    }
  }
  expect_failures = [terraform_data.firewall_contract["bad"]]
}

run "reject_slash_in_identity_keys" {
  command = plan
  variables {
    firewalls = {
      "bad/key" = {
        name       = "bad"
        policy_arn = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/policy"
        placement  = { vpc = { vpc_id = "vpc-1", endpoint_subnets = { "bad/zone" = { subnet_id = "subnet-1" } } } }
      }
    }
  }
  expect_failures = [terraform_data.firewall_contract["bad/key"]]
}
