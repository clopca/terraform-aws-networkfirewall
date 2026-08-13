terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.59, < 7.0"
    }
  }
}

resource "aws_networkfirewall_firewall" "anfw" {
  name                = "stateful-migration"
  firewall_policy_arn = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/stateful"
  vpc_id              = "vpc-0123456789abcdef0"

  delete_protection                 = false
  firewall_policy_change_protection = false
  subnet_change_protection          = false

  subnet_mapping {
    subnet_id       = "subnet-0123456789abcdef0"
    ip_address_type = "IPV4"
  }
}

module "logging" {
  count  = 1
  source = "./logging-v1"

  firewall_arn = aws_networkfirewall_firewall.anfw.arn
}

resource "aws_route" "protected_route_table_to_internet" {
  count = 1

  route_table_id         = "rtb-0123456789abcdef0"
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = "vpce-0123456789abcdef0"
}

output "firewall_id" {
  value = aws_networkfirewall_firewall.anfw.id
}

output "logging_id" {
  value = module.logging[0].id
}

output "route_id" {
  value = aws_route.protected_route_table_to_internet[0].id
}
