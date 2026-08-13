terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.59, < 7.0"
    }
  }
}

variable "firewall_keys" {
  description = "Ordered firewall keys used by the lifecycle test."
  type        = list(string)
}

variable "logging_keys" {
  description = "Ordered logging keys used by the lifecycle test."
  type        = list(string)
}

variable "route_keys" {
  description = "Ordered route keys used by the lifecycle test."
  type        = list(string)
}

locals {
  subnets = {
    alpha   = "subnet-01111111111111111"
    beta    = "subnet-02222222222222222"
    gamma   = "subnet-03333333333333333"
    renamed = "subnet-01111111111111111"
  }
  route_tables = {
    alpha   = "rtb-01111111111111111"
    beta    = "rtb-02222222222222222"
    gamma   = "rtb-03333333333333333"
    renamed = "rtb-01111111111111111"
  }
  destinations = {
    alpha   = "10.1.0.0/16"
    beta    = "10.2.0.0/16"
    gamma   = "10.3.0.0/16"
    renamed = "10.1.0.0/16"
  }
  firewall_names = {
    alpha   = "key-lifecycle-alpha"
    beta    = "key-lifecycle-beta"
    gamma   = "key-lifecycle-gamma"
    renamed = "key-lifecycle-alpha"
  }
  firewall_arns = {
    alpha   = "arn:aws:network-firewall:us-east-1:123456789012:firewall/alpha"
    beta    = "arn:aws:network-firewall:us-east-1:123456789012:firewall/beta"
    gamma   = "arn:aws:network-firewall:us-east-1:123456789012:firewall/gamma"
    renamed = "arn:aws:network-firewall:us-east-1:123456789012:firewall/alpha"
  }
}

module "firewalls" {
  source = "../../.."

  firewalls = {
    for key in var.firewall_keys : key => {
      name       = local.firewall_names[key]
      policy_arn = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/key-lifecycle"
      placement = {
        vpc = {
          vpc_id = "vpc-0123456789abcdef0"
          endpoint_subnets = {
            "us-east-1a" = { subnet_id = local.subnets[key] }
          }
        }
      }
    }
  }
}

module "logging" {
  source = "../../../modules/logging"

  logging_configurations = {
    for key in var.logging_keys : key => {
      firewall_arn = local.firewall_arns[key]
      logs = {
        alerts = {
          log_type    = "ALERT"
          destination = { s3 = { bucket_name = "key-lifecycle-logs" } }
        }
      }
    }
  }
}

module "routes" {
  source = "../../../modules/routes"

  vpc_endpoint_ids_by_az = { "us-east-1a" = "vpce-0123456789abcdef0" }
  routes = {
    for key in var.route_keys : key => {
      route_table_id                   = local.route_tables[key]
      availability_zone                = "us-east-1a"
      acknowledge_external_route_table = true
      destination                      = { ipv4_cidr = local.destinations[key] }
    }
  }
}

output "firewall_ids" {
  value = module.firewalls.firewall_ids
}

output "logging_ids" {
  value = { for key, resource in module.logging.resources.logging_configurations : key => resource.id }
}

output "route_ids" {
  value = module.routes.route_ids
}
