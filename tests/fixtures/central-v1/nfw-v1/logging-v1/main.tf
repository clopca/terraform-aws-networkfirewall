terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.59, < 7.0"
    }
  }
}

variable "firewall_arn" {
  type = string
}

resource "aws_networkfirewall_logging_configuration" "anfw_logs" {
  firewall_arn = var.firewall_arn

  logging_configuration {
    log_destination_config {
      log_type             = "ALERT"
      log_destination_type = "CloudWatchLogs"
      log_destination      = { logGroup = "/aws/network-firewall/central-alerts" }
    }
  }
}

output "id" {
  value = aws_networkfirewall_logging_configuration.anfw_logs.id
}
