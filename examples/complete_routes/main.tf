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

module "network_firewall" {
  source = "../.."

  firewalls = {
    primary = {
      name       = "example-routed-inspection"
      policy_arn = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/example"
      placement = { vpc = {
        vpc_id = "vpc-0123456789abcdef0"
        endpoint_subnets = {
          "us-east-1a" = { subnet_id = "subnet-01111111111111111" }
          "us-east-1b" = { subnet_id = "subnet-02222222222222222" }
        }
      } }
    }
  }
}

module "network_firewall_routes" {
  source = "../../modules/routes"

  vpc_endpoint_ids_by_az = module.network_firewall.vpc_endpoint_ids_by_firewall_by_az.primary

  routes = {
    workload-a-default = {
      route_table_id                   = "rtb-01111111111111111"
      availability_zone                = "us-east-1a"
      acknowledge_external_route_table = true
      destination                      = { ipv4_cidr = "0.0.0.0/0" }
    }
    workload-b-default = {
      route_table_id                   = "rtb-02222222222222222"
      availability_zone                = "us-east-1b"
      acknowledge_external_route_table = true
      destination                      = { ipv4_cidr = "0.0.0.0/0" }
    }
  }
}

output "route_ids" {
  value = {
    for key, route in module.network_firewall_routes.resources.routes : key => route.id
  }
}
