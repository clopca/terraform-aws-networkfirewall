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

module "vpc" {
  source  = "aws-ia/vpc/aws"
  version = "~> 5.0"

  vpc = { name = "example-end-to-end-inspection" }

  addressing = {
    primary = { cidr_block = "10.20.0.0/16" }
  }

  availability_zones = {
    names = ["us-east-1a", "us-east-1b"]
  }

  subnets = {
    public = {
      role    = "public"
      ipv4    = { netmask = 28, cidr_index = 0 }
      routing = { internet_gateway = true }
    }
    firewall = {
      role    = "private"
      ipv4    = { netmask = 28, cidr_index = 1 }
      routing = { nat_gateway = true }
    }
    application = {
      role = "private"
      ipv4 = { netmask = 24, cidr_index = 10 }
    }
  }

  nat_gateway = {
    mode         = "all_azs"
    subnet_group = "public"
  }

  routes = {
    application_default = {
      from_group  = "application"
      destination = { type = "ipv4_cidr", value = "0.0.0.0/0" }
      target = {
        type      = "vpc_endpoint"
        ids_by_az = module.network_firewall.vpc_endpoint_ids_by_firewall_by_az.primary
      }
    }
    public_application_return = {
      from_group  = "public"
      destination = { type = "ipv4_cidr", value = "10.20.10.0/24" }
      target = {
        type      = "vpc_endpoint"
        ids_by_az = module.network_firewall.vpc_endpoint_ids_by_firewall_by_az.primary
      }
    }
  }

  tags = { Environment = "example" }
}

module "rule_groups" {
  source = "../../modules/rule-groups"

  rule_groups = {
    egress-v1 = {
      name       = "example-end-to-end-egress-v1"
      type       = "STATEFUL"
      capacity   = 100
      rule_order = "STRICT_ORDER"

      source = {
        rules_string = <<-RULES
          alert http $HOME_NET any -> $EXTERNAL_NET any (msg:"Example HTTP visibility"; flow:to_server,established; sid:4200001; rev:1;)
        RULES
      }

      ip_sets           = { HOME_NET = ["10.20.0.0/16"] }
      required_ip_sets  = ["HOME_NET"]
      requires_home_net = true
      sid_range         = { min = 4200000, max = 4200099 }

      source_validation = {
        mode          = "attested"
        manifest_uri  = "s3://replace-with-evidence/end-to-end-egress-v1/manifest.json"
        bundle_sha256 = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
      }
    }
  }
}

locals {
  egress_record = module.rule_groups.rule_group_records["egress-v1"]
}

module "policy_control" {
  source = "../../modules/policy-control"

  rule_group_records = module.rule_groups.rule_group_records

  policies = {
    active-2026-08-13-plain = {
      name           = "example-end-to-end-active-2026-08-13-plain"
      enforcement    = { mode = "observation" }
      home_net_cidrs = ["10.20.0.0/16"]
      stateful_rule_groups = {
        egress = {
          arn               = local.egress_record.arn
          priority          = 100
          kind              = local.egress_record.kind
          rule_order        = local.egress_record.rule_order
          declared_capacity = local.egress_record.declared_capacity
          requires_home_net = local.egress_record.requires_home_net
          enforce_from      = "observation"
          behavior = {
            actions             = ["alert"]
            has_terminal_action = false
            override_coverage   = "none"
          }
        }
      }
    }
  }
}

module "network_firewall" {
  source = "../.."

  firewalls = {
    primary = {
      name       = "example-end-to-end-inspection"
      policy_arn = module.policy_control.policy_arns["active-2026-08-13-plain"]
      placement = { vpc = {
        vpc_id = module.vpc.vpc_id
        endpoint_subnets = {
          for az, subnet_id in module.vpc.subnet_ids_by_group_by_az.firewall :
          az => { subnet_id = subnet_id }
        }
      } }
      tags = { Environment = "example" }
    }
  }
}

module "logging" {
  source = "../../modules/logging"

  logging_configurations = {
    primary = {
      firewall_arn = module.network_firewall.firewall_arns.primary
      logs = {
        alert = {
          log_type = "ALERT"
          destination = {
            cloudwatch = {
              log_group_name    = "/aws/network-firewall/example-end-to-end/alert"
              retention_in_days = 30
            }
          }
        }
        flow = {
          log_type = "FLOW"
          destination = {
            cloudwatch = {
              log_group_name    = "/aws/network-firewall/example-end-to-end/flow"
              retention_in_days = 30
            }
          }
        }
      }
    }
  }
}

output "composition" {
  value = {
    vpc_id               = module.vpc.vpc_id
    firewall_arn         = module.network_firewall.firewall_arns.primary
    endpoint_ids_by_az   = module.network_firewall.vpc_endpoint_ids_by_firewall_by_az.primary
    policy_arn           = module.policy_control.policy_arns["active-2026-08-13-plain"]
    rule_group_arn       = module.rule_groups.rule_group_arns["egress-v1"]
    logging_destinations = module.logging.logging_destination_records.primary
  }
}
