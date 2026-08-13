terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.59, < 7.0"
    }
  }
}

resource "aws_networkfirewall_firewall" "this" {
  for_each = { primary = true }

  name                = "stateful-migration"
  firewall_policy_arn = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/stateful"
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

module "logging" {
  source = "../../../modules/logging"

  logging_configurations = {
    primary = {
      firewall_arn = aws_networkfirewall_firewall.this["primary"].arn
      logs = {
        alerts = {
          log_type    = "ALERT"
          destination = { s3 = { bucket_name = "stateful-migration-logs" } }
        }
      }
    }
  }
}

module "routes" {
  source = "../../../modules/routes"

  vpc_endpoint_ids_by_az = { "us-east-1a" = "vpce-0123456789abcdef0" }
  routes = {
    public-a-default-v4 = {
      route_table_id                   = "rtb-0123456789abcdef0"
      availability_zone                = "us-east-1a"
      acknowledge_external_route_table = true
      destination                      = { ipv4_cidr = "0.0.0.0/0" }
    }
  }
}

output "firewall_id" {
  value = aws_networkfirewall_firewall.this["primary"].id
}

output "logging_id" {
  value = module.logging.resources.logging_configurations["primary"].id
}

output "route_id" {
  value = module.routes.resources.routes["public-a-default-v4"].id
}
