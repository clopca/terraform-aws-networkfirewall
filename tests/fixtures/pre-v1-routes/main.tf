terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.59, < 7.0"
    }
  }
}

resource "aws_route" "tgw_to_firewall_endpoint" {
  count = 6

  route_table_id         = format("rtb-%017x", count.index + 1)
  destination_cidr_block = format("10.%d.0.0/16", count.index)
  vpc_endpoint_id        = "vpce-0123456789abcdef0"
}

resource "aws_route" "tgw_to_firewall_endpoint_without_egress" {
  count = 6

  route_table_id         = format("rtb-%017x", count.index + 101)
  destination_cidr_block = format("172.%d.0.0/16", count.index + 16)
  vpc_endpoint_id        = "vpce-0123456789abcdef0"
}

output "egress_route_ids" {
  value = { for index, route in aws_route.tgw_to_firewall_endpoint : tostring(index) => route.id }
}

output "without_egress_route_ids" {
  value = { for index, route in aws_route.tgw_to_firewall_endpoint_without_egress : tostring(index) => route.id }
}
