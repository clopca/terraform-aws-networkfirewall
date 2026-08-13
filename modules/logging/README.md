# Logging module

Configures the single AWS Network Firewall logging configuration for each caller-keyed firewall. Each `firewall_arn` may appear in exactly one `logging_configurations` entry; duplicate ARNs fail plan so two Terraform addresses cannot compete for the same AWS object. Each of `ALERT`, `FLOW`, and `TLS` may appear once and must select exactly one destination.

CloudWatch Logs supports create or inject because a log group's retention, KMS key, and tags form a bounded lifecycle. S3 and Firehose are inject-only: bucket policy, Object Lock, ownership, retention, buffering, delivery IAM, and downstream storage require dedicated modules and must not be hidden behind a shallow logging flag.

`manage = false` removes the effective `aws_networkfirewall_logging_configuration`; it is a lifecycle handoff, not a harmless enable/disable switch. Changing `monitoring_dashboard` causes provider 6.60 to remove every `log_destination_config`, change the dashboard setting, and reinstall the destinations, creating a potential logging gap. Plan that change separately from migrations and security changes.

Use `logging_destination_records` for composition. The `resources` output is an implementation escape hatch without a stable shape guarantee.
