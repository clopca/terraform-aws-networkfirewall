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

module "rule_groups" {
  source = "../../modules/rule-groups"

  rule_groups = {
    egress-v1 = {
      name       = "inspection-egress-v1"
      type       = "STATEFUL"
      capacity   = 500
      rule_order = "STRICT_ORDER"

      source = {
        rules_string = file("${path.module}/egress.rules")
      }

      ip_sets = {
        WORKLOADS = ["10.0.0.0/8"]
      }
      port_sets = {
        WEB_PORTS = ["80", "443"]
      }
      required_ip_sets   = ["WORKLOADS"]
      required_port_sets = ["WEB_PORTS"]
      requires_home_net  = true
      sid_range          = { min = 4100000, max = 4100099 }

      source_validation = {
        mode          = "attested"
        manifest_uri  = "s3://security-rule-attestations/egress-v1/manifest.json"
        bundle_sha256 = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
      }
    }
  }
}

output "rule_group_records" {
  value = module.rule_groups.rule_group_records
}
