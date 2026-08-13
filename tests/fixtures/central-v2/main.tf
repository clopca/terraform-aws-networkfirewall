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
  source = "../../.."

  firewalls = {
    primary = {
      name        = "central-migration"
      description = "Central inspection migration fixture"
      policy_arn  = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/central"
      placement = { vpc = {
        vpc_id = "vpc-0123456789abcdef0"
        endpoint_subnets = {
          "us-east-1a" = { subnet_id = "subnet-aaaaaaaaaaaaaaaaa", availability_zone_id = "use1-az1" }
          "us-east-1b" = { subnet_id = "subnet-bbbbbbbbbbbbbbbbb", availability_zone_id = "use1-az2" }
        }
      } }
      protections = { delete = false, policy_change = false, subnet_change = false, availability_zone_change = false }
      encryption  = { type = "CUSTOMER_KMS", key_arn = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000001" }
      tags = {
        Environment = "migration"
        Owner       = "network-security"
      }
    }
  }
}

module "nfw_logging" {
  source = "../../../modules/logging"

  logging_configurations = {
    primary = {
      firewall_arn = module.nfw.firewall_arns.primary
      logs = {
        alerts = {
          log_type = "ALERT"
          destination = { cloudwatch = {
            create         = false
            log_group_name = "/aws/network-firewall/central-alerts"
          } }
        }
      }
    }
  }
}

module "nfw_routes" {
  source = "../../../modules/routes"

  vpc_endpoint_ids_by_az = {
    "us-east-1a" = "vpce-aaaaaaaaaaaaaaaaa"
    "us-east-1b" = "vpce-bbbbbbbbbbbbbbbbb"
  }

  routes = {
    tgw-a-default    = { route_table_id = "rtb-00000000000000001", availability_zone = "us-east-1a", acknowledge_external_route_table = true, destination = { ipv4_cidr = "0.0.0.0/0" } }
    tgw-b-default    = { route_table_id = "rtb-00000000000000002", availability_zone = "us-east-1b", acknowledge_external_route_table = true, destination = { ipv4_cidr = "0.0.0.0/0" } }
    public-a-spoke-0 = { route_table_id = "rtb-00000000000000011", availability_zone = "us-east-1a", acknowledge_external_route_table = true, destination = { ipv4_cidr = "10.10.0.0/16" } }
    public-a-spoke-1 = { route_table_id = "rtb-00000000000000011", availability_zone = "us-east-1a", acknowledge_external_route_table = true, destination = { ipv4_cidr = "10.20.0.0/16" } }
    public-b-spoke-0 = { route_table_id = "rtb-00000000000000012", availability_zone = "us-east-1b", acknowledge_external_route_table = true, destination = { ipv4_cidr = "10.10.0.0/16" } }
    public-b-spoke-1 = { route_table_id = "rtb-00000000000000012", availability_zone = "us-east-1b", acknowledge_external_route_table = true, destination = { ipv4_cidr = "10.20.0.0/16" } }
  }
}

output "firewall" {
  value = {
    id                                  = module.nfw.resources.firewalls["primary"].id
    description                         = module.nfw.resources.firewalls["primary"].description
    policy_arn                          = module.nfw.resources.firewalls["primary"].firewall_policy_arn
    delete_protection                   = module.nfw.resources.firewalls["primary"].delete_protection
    policy_change_protection            = module.nfw.resources.firewalls["primary"].firewall_policy_change_protection
    subnet_change_protection            = module.nfw.resources.firewalls["primary"].subnet_change_protection
    availability_zone_change_protection = module.nfw.resources.firewalls["primary"].availability_zone_change_protection
    encryption_key                      = module.nfw.resources.firewalls["primary"].encryption_configuration[0].key_id
    tags                                = module.nfw.resources.firewalls["primary"].tags
    subnet_ids                          = toset([for mapping in module.nfw.resources.firewalls["primary"].subnet_mapping : mapping.subnet_id])
  }
}

output "logging_id" {
  value = module.nfw_logging.resources.logging_configurations["primary"].id
}

output "cloudwatch_log_group_count" {
  value = length(module.nfw_logging.resources.cloudwatch_log_groups)
}

output "connectivity_route_ids" {
  value = {
    "0" = module.nfw_routes.resources.routes["tgw-a-default"].id
    "1" = module.nfw_routes.resources.routes["tgw-b-default"].id
  }
}

output "central_route_ids" {
  value = {
    "0/0" = module.nfw_routes.resources.routes["public-a-spoke-0"].id
    "0/1" = module.nfw_routes.resources.routes["public-a-spoke-1"].id
    "1/0" = module.nfw_routes.resources.routes["public-b-spoke-0"].id
    "1/1" = module.nfw_routes.resources.routes["public-b-spoke-1"].id
  }
}
