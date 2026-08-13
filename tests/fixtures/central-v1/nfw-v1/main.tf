terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.59, < 7.0"
    }
  }
}

locals {
  endpoint_ids        = ["vpce-aaaaaaaaaaaaaaaaa", "vpce-bbbbbbbbbbbbbbbbb"]
  connectivity_tables = ["rtb-00000000000000001", "rtb-00000000000000002"]
  public_tables       = ["rtb-00000000000000011", "rtb-00000000000000012"]
  spoke_cidrs         = ["10.10.0.0/16", "10.20.0.0/16"]
}

resource "aws_networkfirewall_firewall" "anfw" {
  name                = "central-migration"
  description         = "Central inspection migration fixture"
  firewall_policy_arn = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/central"
  vpc_id              = "vpc-0123456789abcdef0"

  delete_protection                   = false
  firewall_policy_change_protection   = false
  subnet_change_protection            = false
  availability_zone_change_protection = false

  subnet_mapping {
    subnet_id       = "subnet-aaaaaaaaaaaaaaaaa"
    ip_address_type = "IPV4"
  }
  subnet_mapping {
    subnet_id       = "subnet-bbbbbbbbbbbbbbbbb"
    ip_address_type = "IPV4"
  }

  encryption_configuration {
    type   = "CUSTOMER_KMS"
    key_id = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000001"
  }

  tags = {
    Environment = "migration"
    Owner       = "network-security"
  }
}

module "logging" {
  count  = 1
  source = "./logging-v1"

  firewall_arn = aws_networkfirewall_firewall.anfw.arn
}

resource "aws_route" "connectivity_to_firewall_endpoint" {
  count = 2

  route_table_id         = local.connectivity_tables[count.index]
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = local.endpoint_ids[count.index]
}

module "central_inspection_with_egress_routing" {
  count  = 2
  source = "./central-routes-v1"

  route_table_id  = local.public_tables[count.index]
  vpc_endpoint_id = local.endpoint_ids[count.index]
  destinations    = local.spoke_cidrs
}

output "firewall" {
  value = {
    id                                  = aws_networkfirewall_firewall.anfw.id
    description                         = aws_networkfirewall_firewall.anfw.description
    policy_arn                          = aws_networkfirewall_firewall.anfw.firewall_policy_arn
    delete_protection                   = aws_networkfirewall_firewall.anfw.delete_protection
    policy_change_protection            = aws_networkfirewall_firewall.anfw.firewall_policy_change_protection
    subnet_change_protection            = aws_networkfirewall_firewall.anfw.subnet_change_protection
    availability_zone_change_protection = aws_networkfirewall_firewall.anfw.availability_zone_change_protection
    encryption_key                      = aws_networkfirewall_firewall.anfw.encryption_configuration[0].key_id
    tags                                = aws_networkfirewall_firewall.anfw.tags
    subnet_ids                          = toset([for mapping in aws_networkfirewall_firewall.anfw.subnet_mapping : mapping.subnet_id])
  }
}

output "logging_id" {
  value = module.logging[0].id
}

output "connectivity_route_ids" {
  value = { for index, route in aws_route.connectivity_to_firewall_endpoint : tostring(index) => route.id }
}

output "central_route_ids" {
  value = merge([for az_index, route_module in module.central_inspection_with_egress_routing : {
    for cidr_index, route_id in route_module.route_ids : "${az_index}/${cidr_index}" => route_id
  }]...)
}
