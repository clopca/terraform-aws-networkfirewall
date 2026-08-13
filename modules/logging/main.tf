locals {
  valid_retention_days = toset([
    0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096,
    1827, 2192, 2557, 2922, 3288, 3653,
  ])

  cloudwatch_log_groups = merge(concat([{}], [
    for configuration_key, configuration in var.logging_configurations : {
      for log_key, log in configuration.logs : "${configuration_key}/${log_key}" => log.destination.cloudwatch
      if log.destination.cloudwatch != null && log.destination.cloudwatch.create
    }
  ])...)
}

resource "terraform_data" "logging_contract" {
  for_each = var.logging_configurations

  input = each.key

  lifecycle {
    precondition {
      condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9_.-]*$", each.key))
      error_message = "Logging configuration key '${each.key}' is invalid. Use letters, numbers, '.', '_', or '-' and do not include '/'."
    }

    precondition {
      condition     = trimspace(each.value.firewall_arn) != ""
      error_message = "Logging configuration '${each.key}' requires a non-empty firewall_arn. Supply the Tier 1 firewall ARN."
    }

    precondition {
      condition     = !each.value.manage || (length(each.value.logs) >= 1 && length(each.value.logs) <= 3)
      error_message = "Managed logging configuration '${each.key}' must contain one to three logs. Add ALERT, FLOW, or TLS entries, each at most once."
    }

    precondition {
      condition = alltrue([
        for log_key in keys(each.value.logs) : can(regex("^[A-Za-z0-9][A-Za-z0-9_.-]*$", log_key))
      ])
      error_message = "Logging configuration '${each.key}' has an invalid log key. Use letters, numbers, '.', '_', or '-' and do not include '/'."
    }

    precondition {
      condition = alltrue([
        for log in values(each.value.logs) : contains(["ALERT", "FLOW", "TLS"], log.log_type)
      ])
      error_message = "Logging configuration '${each.key}' has an invalid log_type. Use ALERT, FLOW, or TLS."
    }

    precondition {
      condition = length(distinct([
        for log in values(each.value.logs) : log.log_type
      ])) == length(each.value.logs)
      error_message = "Logging configuration '${each.key}' repeats a log_type. Keep exactly one caller-keyed destination for each of ALERT, FLOW, and TLS."
    }

    precondition {
      condition = alltrue([
        for log in values(each.value.logs) : length(compact([
          log.destination.cloudwatch != null ? "cloudwatch" : "",
          log.destination.s3 != null ? "s3" : "",
          log.destination.firehose != null ? "firehose" : "",
        ])) == 1
      ])
      error_message = "Logging configuration '${each.key}' has a log with zero or multiple destinations. Set exactly one of cloudwatch, s3, or firehose."
    }

    precondition {
      condition = alltrue([
        for log in values(each.value.logs) : (
          log.destination.cloudwatch == null || (
            trimspace(log.destination.cloudwatch.log_group_name) != "" &&
            contains(local.valid_retention_days, log.destination.cloudwatch.retention_in_days)
          )
        )
      ])
      error_message = "Logging configuration '${each.key}' has an invalid CloudWatch destination. Supply log_group_name and a supported retention_in_days value."
    }

    precondition {
      condition = alltrue([
        for log in values(each.value.logs) : (
          log.destination.s3 == null || trimspace(log.destination.s3.bucket_name) != ""
          ) && (
          log.destination.firehose == null || trimspace(log.destination.firehose.delivery_stream_name) != ""
        )
      ])
      error_message = "Logging configuration '${each.key}' has an empty S3 bucket or Firehose delivery stream name. Supply the existing destination name."
    }
  }
}

resource "aws_cloudwatch_log_group" "this" {
  for_each = local.cloudwatch_log_groups

  name              = each.value.log_group_name
  retention_in_days = each.value.retention_in_days
  kms_key_id        = each.value.kms_key_arn
  tags              = each.value.tags

  depends_on = [terraform_data.logging_contract]
}

locals {
  logging_destination_records = {
    for configuration_key, configuration in var.logging_configurations : configuration_key => {
      for log_key, log in configuration.logs : log_key => {
        log_type = log.log_type
        destination_type = (
          log.destination.cloudwatch != null ? "CloudWatchLogs" :
          log.destination.s3 != null ? "S3" : "KinesisDataFirehose"
        )
        destination = (
          log.destination.cloudwatch != null ? {
            logGroup = log.destination.cloudwatch.create ? aws_cloudwatch_log_group.this["${configuration_key}/${log_key}"].name : log.destination.cloudwatch.log_group_name
            } : log.destination.s3 != null ? merge(
            { bucketName = log.destination.s3.bucket_name },
            log.destination.s3.prefix == null ? {} : { prefix = log.destination.s3.prefix },
            ) : {
            deliveryStream = log.destination.firehose.delivery_stream_name
          }
        )
        managed = log.destination.cloudwatch != null && log.destination.cloudwatch.create
      }
    }
  }
}

resource "aws_networkfirewall_logging_configuration" "this" {
  for_each = {
    for key, configuration in var.logging_configurations : key => configuration if configuration.manage
  }

  firewall_arn                = each.value.firewall_arn
  enable_monitoring_dashboard = each.value.monitoring_dashboard

  logging_configuration {
    dynamic "log_destination_config" {
      for_each = local.logging_destination_records[each.key]

      content {
        log_type             = log_destination_config.value.log_type
        log_destination_type = log_destination_config.value.destination_type
        log_destination      = log_destination_config.value.destination
      }
    }
  }

  depends_on = [terraform_data.logging_contract]
}
