terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.59, < 7.0"
    }
  }
}

resource "aws_networkfirewall_firewall" "created" {
  name                = "create-inject-composition-source"
  firewall_policy_arn = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/source"
  vpc_id              = "vpc-0123456789abcdef0"

  subnet_mapping {
    subnet_id = "subnet-aaaaaaaaaaaaaaaaa"
  }
}

module "injected" {
  source = "../../.."

  firewalls = {
    observed = {
      create = false
      arn    = aws_networkfirewall_firewall.created.arn
      placement = { vpc = {
        vpc_id = "vpc-0123456789abcdef0"
        endpoint_subnets = {
          "us-east-1a" = {
            subnet_id            = "subnet-aaaaaaaaaaaaaaaaa"
            availability_zone_id = "use1-az1"
          }
        }
      } }
    }
  }
}

output "injected_firewall_keys" {
  value = keys(module.injected.firewall_arns)
}
