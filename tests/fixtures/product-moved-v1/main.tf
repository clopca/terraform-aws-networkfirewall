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
  name                = "product-moved"
  firewall_policy_arn = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/product-moved"
  vpc_id              = "vpc-0123456789abcdef0"

  delete_protection                   = false
  firewall_policy_change_protection   = false
  subnet_change_protection            = false
  availability_zone_change_protection = false

  subnet_mapping {
    subnet_id       = "subnet-0123456789abcdef0"
    ip_address_type = "IPV4"
  }
}

output "firewall_id" {
  value = aws_networkfirewall_firewall.anfw.id
}
