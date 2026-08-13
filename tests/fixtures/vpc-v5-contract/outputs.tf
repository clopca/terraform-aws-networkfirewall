locals {
  subnet_ids_by_group_by_az = {
    for group_key, group in var.subnets : group_key => {
      for index, az in var.availability_zones.names :
      az => "subnet-documentation-${group_key}-${index}"
    }
  }

  route_table_ids_by_group_by_az = {
    for group_key, group in var.subnets : group_key => {
      for index, az in var.availability_zones.names :
      az => "rtb-documentation-${group_key}-${index}"
    }
  }
}

output "vpc_id" {
  description = "Placeholder VPC ID used only during static validation."
  value       = "vpc-documentation-contract"
}

output "subnet_ids_by_group_by_az" {
  description = "Placeholder subnet IDs preserving the VPC v5 group/AZ shape."
  value       = local.subnet_ids_by_group_by_az
}

output "route_table_ids_by_group_by_az" {
  description = "Placeholder route-table IDs preserving the VPC v5 group/AZ shape."
  value       = local.route_table_ids_by_group_by_az
}

output "nat_gateway_ids" {
  description = "Placeholder zonal NAT Gateway IDs."
  value = {
    for index, az in var.availability_zones.names :
    az => "nat-documentation-${index}"
  }
}

output "internet_gateway_id" {
  description = "Placeholder Internet Gateway ID."
  value       = "igw-documentation-contract"
}
