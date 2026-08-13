mock_provider "aws" {
  override_during = plan

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      id   = "/aws/network-firewall/mock"
      arn  = "arn:aws:logs:us-east-1:123456789012:log-group:/aws/network-firewall/mock"
      name = "/aws/network-firewall/mock"
    }
  }

  mock_resource "aws_networkfirewall_logging_configuration" {
    defaults = { id = "logging-mock" }
  }
}

run "plan_all_logging_destinations" {
  command = plan

  module { source = "./modules/logging" }

  variables {
    logging_configurations = {
      primary = {
        firewall_arn         = "arn:aws:network-firewall:us-east-1:123456789012:firewall/inspection"
        monitoring_dashboard = true
        logs = {
          alerts = {
            log_type = "ALERT"
            destination = {
              cloudwatch = {
                log_group_name    = "/aws/network-firewall/alerts"
                retention_in_days = 90
              }
            }
          }
          flows = {
            log_type = "FLOW"
            destination = {
              s3 = { bucket_name = "network-firewall-logs", prefix = "flow" }
            }
          }
          tls = {
            log_type = "TLS"
            destination = {
              firehose = { delivery_stream_name = "network-firewall-tls" }
            }
          }
        }
      }
    }
  }

  assert {
    condition = (
      length(aws_cloudwatch_log_group.this) == 1 &&
      length(aws_networkfirewall_logging_configuration.this) == 1 &&
      toset(keys(output.logging_destination_records.primary)) == toset(["alerts", "flows", "tls"])
    )
    error_message = "Logging must support ALERT, FLOW, and TLS with one closed destination per type."
  }
}

run "inject_cloudwatch_log_group" {
  command = plan

  module { source = "./modules/logging" }

  variables {
    logging_configurations = {
      primary = {
        firewall_arn = "arn:aws:network-firewall:us-east-1:123456789012:firewall/inspection"
        logs = {
          alerts = {
            log_type = "ALERT"
            destination = {
              cloudwatch = {
                create         = false
                log_group_name = "/existing/network-firewall/alerts"
              }
            }
          }
        }
      }
    }
  }

  assert {
    condition = (
      length(aws_cloudwatch_log_group.this) == 0 &&
      output.logging_destination_records.primary.alerts.destination.logGroup == "/existing/network-firewall/alerts"
    )
    error_message = "Injected CloudWatch destinations must not create or adopt a log group."
  }
}

run "reject_duplicate_log_types" {
  command = plan
  module { source = "./modules/logging" }
  variables {
    logging_configurations = {
      bad = {
        firewall_arn = "arn:aws:network-firewall:us-east-1:123456789012:firewall/test"
        logs = {
          first  = { log_type = "ALERT", destination = { s3 = { bucket_name = "logs" } } }
          second = { log_type = "ALERT", destination = { firehose = { delivery_stream_name = "logs" } } }
        }
      }
    }
  }
  expect_failures = [terraform_data.logging_contract["bad"]]
}

run "reject_invalid_log_type" {
  command = plan
  module { source = "./modules/logging" }
  variables {
    logging_configurations = {
      bad = {
        firewall_arn = "arn:aws:network-firewall:us-east-1:123456789012:firewall/test"
        logs         = { audit = { log_type = "AUDIT", destination = { s3 = { bucket_name = "logs" } } } }
      }
    }
  }
  expect_failures = [terraform_data.logging_contract["bad"]]
}

run "reject_multiple_destinations" {
  command = plan
  module { source = "./modules/logging" }
  variables {
    logging_configurations = {
      bad = {
        firewall_arn = "arn:aws:network-firewall:us-east-1:123456789012:firewall/test"
        logs = {
          alerts = {
            log_type = "ALERT"
            destination = {
              s3       = { bucket_name = "logs" }
              firehose = { delivery_stream_name = "logs" }
            }
          }
        }
      }
    }
  }
  expect_failures = [terraform_data.logging_contract["bad"]]
}

run "reject_unknown_retention" {
  command = plan
  module { source = "./modules/logging" }
  variables {
    logging_configurations = {
      bad = {
        firewall_arn = "arn:aws:network-firewall:us-east-1:123456789012:firewall/test"
        logs = {
          alerts = {
            log_type    = "ALERT"
            destination = { cloudwatch = { log_group_name = "/logs", retention_in_days = 13 } }
          }
        }
      }
    }
  }
  expect_failures = [terraform_data.logging_contract["bad"]]
}

run "reject_slash_in_logging_key" {
  command = plan
  module { source = "./modules/logging" }
  variables {
    logging_configurations = {
      "bad/key" = {
        firewall_arn = "arn:aws:network-firewall:us-east-1:123456789012:firewall/test"
        logs         = { alerts = { log_type = "ALERT", destination = { s3 = { bucket_name = "logs" } } } }
      }
    }
  }
  expect_failures = [terraform_data.logging_contract["bad/key"]]
}
