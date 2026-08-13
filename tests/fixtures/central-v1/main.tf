terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.59, < 7.0"
    }
  }
}

module "nfw" {
  source = "./nfw-v1"
}

output "firewall" {
  value = module.nfw.firewall
}

output "logging_id" {
  value = module.nfw.logging_id
}

output "connectivity_route_ids" {
  value = module.nfw.connectivity_route_ids
}

output "central_route_ids" {
  value = module.nfw.central_route_ids
}
