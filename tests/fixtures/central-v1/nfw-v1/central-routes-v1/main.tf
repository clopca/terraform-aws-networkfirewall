terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.59, < 7.0"
    }
  }
}

variable "route_table_id" {
  type = string
}
variable "vpc_endpoint_id" {
  type = string
}
variable "destinations" {
  type = list(string)
}

resource "aws_route" "route_public_to_firewall_endpoint" {
  count = length(var.destinations)

  route_table_id         = var.route_table_id
  destination_cidr_block = var.destinations[count.index]
  vpc_endpoint_id        = var.vpc_endpoint_id
}

output "route_ids" {
  value = { for index, route in aws_route.route_public_to_firewall_endpoint : tostring(index) => route.id }
}
