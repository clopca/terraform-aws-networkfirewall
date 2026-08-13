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

variable "existing_firewall_arn" {
  description = "ARN of an existing firewall to observe without lifecycle adoption."
  type        = string
  default     = "arn:aws:network-firewall:us-east-1:123456789012:firewall/example"
}

module "network_firewall" {
  source = "../.."

  firewalls = {
    primary = {
      create = false
      arn    = var.existing_firewall_arn
    }
  }
}

output "observed_firewall" {
  value = {
    arn                = module.network_firewall.firewall_arns.primary
    id                 = module.network_firewall.firewall_ids.primary
    name               = module.network_firewall.firewall_names.primary
    policy_arn         = module.network_firewall.firewall_policy_arns.primary
    endpoints_by_az    = module.network_firewall.vpc_endpoint_ids_by_firewall_by_az.primary
    endpoint_readiness = module.network_firewall.vpc_endpoint_records_by_firewall_by_az.primary
  }
}
