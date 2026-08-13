terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.59, < 7.0"
    }
  }
}

module "network_firewall" {
  source = "../.."

  firewalls = {
    primary = {
      name        = "example-inspection"
      description = "Network inspection firewall"
      policy_arn  = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/example"
      placement = {
        vpc = {
          vpc_id = "vpc-0123456789abcdef0"
          endpoint_subnets = {
            "us-east-1a" = {
              subnet_id                    = "subnet-01111111111111111"
              ip_address_type              = "DUALSTACK"
              address_family_migration_ack = true
            }
            "us-east-1b" = {
              subnet_id                    = "subnet-02222222222222222"
              ip_address_type              = "DUALSTACK"
              address_family_migration_ack = true
            }
          }
        }
      }
      tags = { Environment = "example" }
    }
  }
}

output "firewall_arn" {
  value = module.network_firewall.firewall_arns.primary
}

output "vpc_endpoint_ids_by_az" {
  value = module.network_firewall.vpc_endpoint_ids_by_firewall_by_az.primary
}
