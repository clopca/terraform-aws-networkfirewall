# Logging module

Configures the single AWS Network Firewall logging configuration for each caller-keyed firewall. Each of `ALERT`, `FLOW`, and `TLS` may appear once and must select exactly one destination.

CloudWatch Logs supports create or inject because a log group's retention, KMS key, and tags form a bounded lifecycle. S3 and Firehose are inject-only: bucket policy, Object Lock, ownership, retention, buffering, delivery IAM, and downstream storage require dedicated modules and must not be hidden behind a shallow logging flag.

Use `logging_destination_records` for composition. The `resources` output is an implementation escape hatch without a stable shape guarantee.
