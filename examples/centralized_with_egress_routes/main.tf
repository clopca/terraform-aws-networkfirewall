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
  spoke_cidr = "10.0.0.0/8"
  endpoint_subnet_ids_by_az = {
    us-east-1a = "subnet-01111111111111111"
    us-east-1b = "subnet-02222222222222222"
  }
  tgw_attachment_route_table_ids_by_az = {
    us-east-1a = "rtb-01111111111111111"
    us-east-1b = "rtb-02222222222222222"
  }
  firewall_route_table_ids_by_az = {
    us-east-1a = "rtb-03333333333333333"
    us-east-1b = "rtb-04444444444444444"
  }
  nat_route_table_ids_by_az = {
    us-east-1a = "rtb-05555555555555555"
    us-east-1b = "rtb-06666666666666666"
  }
  nat_gateway_ids_by_az = {
    us-east-1a = "nat-01111111111111111"
    us-east-1b = "nat-02222222222222222"
  }
}

variable "transit_gateway_id" {
  type    = string
  default = "tgw-0123456789abcdef0"
}

variable "internet_gateway_id" {
  type    = string
  default = "igw-0123456789abcdef0"
}

module "network_firewall" {
  source = "../.."

  firewalls = {
    primary = {
      name       = "example-central-egress"
      policy_arn = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/example"
      placement = { vpc = {
        vpc_id = "vpc-0123456789abcdef0"
        endpoint_subnets = {
          for az, subnet_id in local.endpoint_subnet_ids_by_az :
          az => { subnet_id = subnet_id }
        }
      } }
    }
  }
}

module "routes_to_firewall" {
  source = "../../modules/routes"

  vpc_endpoint_ids_by_az = module.network_firewall.vpc_endpoint_ids_by_firewall_by_az.primary

  routes = merge(
    {
      for az, route_table_id in local.tgw_attachment_route_table_ids_by_az :
      "tgw_${replace(az, "-", "_")}_default" => {
        route_table_id                   = route_table_id
        destination                      = { ipv4_cidr = "0.0.0.0/0" }
        availability_zone                = az
        acknowledge_external_route_table = true
      }
    },
    {
      for az, route_table_id in local.nat_route_table_ids_by_az :
      "nat_${replace(az, "-", "_")}_spoke_return" => {
        route_table_id                   = route_table_id
        destination                      = { ipv4_cidr = local.spoke_cidr }
        availability_zone                = az
        acknowledge_external_route_table = true
      }
    }
  )
}

resource "aws_route" "firewall_to_nat" {
  for_each = local.firewall_route_table_ids_by_az

  route_table_id         = each.value
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = local.nat_gateway_ids_by_az[each.key]
}

resource "aws_route" "firewall_to_tgw" {
  for_each = local.firewall_route_table_ids_by_az

  route_table_id         = each.value
  destination_cidr_block = local.spoke_cidr
  transit_gateway_id     = var.transit_gateway_id
}

resource "aws_route" "nat_to_internet" {
  for_each = local.nat_route_table_ids_by_az

  route_table_id         = each.value
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = var.internet_gateway_id
}

output "route_ids" {
  value = {
    to_firewall = module.routes_to_firewall.route_ids
    to_nat      = { for az, route in aws_route.firewall_to_nat : az => route.id }
    to_tgw      = { for az, route in aws_route.firewall_to_tgw : az => route.id }
    to_internet = { for az, route in aws_route.nat_to_internet : az => route.id }
  }
}
