terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.59, < 7.0"
    }
  }
}

module "network_firewall" {
  source = "../.."

  firewalls = {
    primary = {
      name       = "example-logged-inspection"
      policy_arn = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/example"
      placement = {
        vpc = {
          vpc_id = "vpc-0123456789abcdef0"
          endpoint_subnets = {
            "us-east-1a" = {
              subnet_id       = "subnet-01111111111111111"
              ip_address_type = "IPV4"
            }
          }
        }
      }
    }
  }
}

module "network_firewall_logging" {
  source = "../../modules/logging"

  logging_configurations = {
    primary = {
      firewall_arn         = module.network_firewall.firewall_arns.primary
      monitoring_dashboard = true
      logs = {
        alerts = {
          log_type = "ALERT"
          destination = {
            cloudwatch = {
              log_group_name    = "/aws/network-firewall/example/alerts"
              retention_in_days = 90
            }
          }
        }
        flows = {
          log_type = "FLOW"
          destination = {
            s3 = {
              bucket_name = "replace-with-existing-log-bucket"
              prefix      = "network-firewall/flow"
            }
          }
        }
        tls = {
          log_type = "TLS"
          destination = {
            firehose = {
              delivery_stream_name = "replace-with-existing-delivery-stream"
            }
          }
        }
      }
    }
  }
}

output "logging_destinations" {
  value = module.network_firewall_logging.logging_destination_records.primary
}
