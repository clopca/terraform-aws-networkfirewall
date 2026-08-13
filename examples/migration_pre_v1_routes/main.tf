terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.59, < 7.0"
    }
  }
}

module "routes" {
  source = "../../modules/routes"

  vpc_endpoint_ids_by_az = {
    "us-east-1a" = "vpce-0123456789abcdef0"
  }

  routes = merge(
    {
      for index in range(6) : "central-egress-${index}" => {
        route_table_id                   = format("rtb-%017x", index + 1)
        availability_zone                = "us-east-1a"
        acknowledge_external_route_table = true
        destination                      = { ipv4_cidr = format("10.%d.0.0/16", index) }
      }
    },
    {
      for index in range(6) : "central-without-egress-${index}" => {
        route_table_id                   = format("rtb-%017x", index + 101)
        availability_zone                = "us-east-1a"
        acknowledge_external_route_table = true
        destination                      = { ipv4_cidr = format("172.%d.0.0/16", index + 16) }
      }
    },
  )
}

output "egress_route_ids" {
  value = { for index in range(6) : tostring(index) => module.routes.resources.routes["central-egress-${index}"].id }
}

output "without_egress_route_ids" {
  value = { for index in range(6) : tostring(index) => module.routes.resources.routes["central-without-egress-${index}"].id }
}
