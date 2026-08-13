# ADR 0001: Module boundaries

## Status

Accepted

## Decision

The root module owns AWS Network Firewall resources and primary VPC endpoint mappings. `modules/logging` owns the single logging configuration for each firewall and may own CloudWatch log groups. `modules/routes` is a temporary adapter that owns only caller-declared `aws_route` resources.

Policy, rule-group, TLS inspection, VPC endpoint association, and sharing modules are reserved for later v2 phases. Transit Gateway firewall placement is also reserved: the input shape records the future variant, but v2.0 rejects it with an actionable plan error.

The root accepts a policy ARN and VPC/subnet handles. It does not create VPCs, subnets, route tables, KMS keys, S3 buckets, or Firehose delivery streams. These boundaries keep independent AWS lifecycles and blast radii independent.
