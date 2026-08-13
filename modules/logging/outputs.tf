output "logging_destination_records" {
  description = "Effective logging destinations by configuration key and log key."
  value       = local.logging_destination_records
}

output "resources" {
  description = "Internal logging resources. This shape is not semver-protected."
  value = {
    logging_configurations = aws_networkfirewall_logging_configuration.this
    cloudwatch_log_groups  = aws_cloudwatch_log_group.this
  }
}
