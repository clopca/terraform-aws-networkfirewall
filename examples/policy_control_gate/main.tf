terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.59, < 7.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

locals {
  managed_arn              = "arn:aws:network-firewall:us-east-1:aws-managed:stateful-rulegroup/ThreatSignaturesStrictOrder"
  customer_enforcement_arn = "arn:aws:network-firewall:us-east-1:123456789012:stateful-rulegroup/egress-enforce-v1"
  customer_observation_arn = "arn:aws:network-firewall:us-east-1:123456789012:stateful-rulegroup/egress-observe-v1"

  common_groups = {
    managed-threats = {
      arn               = local.managed_arn
      priority          = 100
      kind              = "managed"
      rule_order        = "STRICT_ORDER"
      declared_capacity = 1000
      enforce_from      = "enforce"
      behavior = {
        actions             = ["alert", "drop"]
        has_terminal_action = false
        override_coverage   = "all_blocking"
      }
    }
    customer-egress = {
      arn               = local.customer_enforcement_arn
      observation_arn   = local.customer_observation_arn
      priority          = 200
      kind              = "customer"
      rule_order        = "STRICT_ORDER"
      declared_capacity = 500
      enforce_from      = "selective"
      requires_home_net = true
      behavior = {
        actions             = ["alert", "drop"]
        has_terminal_action = false
        override_coverage   = "all_blocking"
      }
    }
  }
}

module "policy_control" {
  source = "../../modules/policy-control"

  policies = {
    candidate-2026-08-13-plain = {
      name                 = "inspection-candidate-2026-08-13-plain"
      enforcement          = { mode = "observation" }
      home_net_cidrs       = ["10.0.0.0/8", "192.168.0.0/16"]
      stateful_rule_groups = local.common_groups
    }

    active-2026-08-12-plain = {
      name                 = "inspection-active-2026-08-12-plain"
      enforcement          = { mode = "selective" }
      home_net_cidrs       = ["10.0.0.0/8", "192.168.0.0/16"]
      stateful_rule_groups = local.common_groups
    }

    last-known-good-2026-08-11-plain = {
      name                 = "inspection-last-known-good-2026-08-11-plain"
      enforcement          = { mode = "enforce" }
      home_net_cidrs       = ["10.0.0.0/8", "192.168.0.0/16"]
      stateful_rule_groups = local.common_groups
    }

    incident-2026-08-13-plain = {
      name                 = "inspection-incident-2026-08-13-plain"
      enforcement          = { mode = "enforce" }
      home_net_cidrs       = ["10.0.0.0/8", "192.168.0.0/16"]
      stateful_rule_groups = local.common_groups
      incident_control = {
        mode            = "observe_all_stateful"
        group_overrides = { customer-egress = "force_enforce" }
        change_id       = "INC-12345"
        owner           = "network-security-oncall"
        expires_at      = "2026-08-14T03:00:00Z"
      }
    }
  }
}

output "policy_roles" {
  value = {
    candidate       = module.policy_control.policy_arns["candidate-2026-08-13-plain"]
    active          = module.policy_control.policy_arns["active-2026-08-12-plain"]
    last_known_good = module.policy_control.policy_arns["last-known-good-2026-08-11-plain"]
  }
}

output "effective_releases" {
  value = module.policy_control.effective_releases
}
