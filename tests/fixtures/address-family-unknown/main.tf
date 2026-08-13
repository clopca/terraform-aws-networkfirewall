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
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

resource "terraform_data" "unknown_ack" {
  input = timestamp() == "never"
}

module "network_firewall" {
  source = "../../.."

  firewalls = {
    primary = {
      name       = "family-unknown"
      policy_arn = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/family"
      placement = { vpc = {
        vpc_id = "vpc-0123456789abcdef0"
        endpoint_subnets = {
          "us-east-1a" = {
            subnet_id                    = "subnet-0123456789abcdef0"
            ip_address_type              = "DUALSTACK"
            address_family_migration_ack = terraform_data.unknown_ack.output
          }
        }
      } }
    }
  }
}
