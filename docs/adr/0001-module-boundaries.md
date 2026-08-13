# ADR 0001: Module boundaries

## Status

Accepted

## Decision

The root module owns AWS Network Firewall resources and primary VPC endpoint mappings. `modules/logging` owns the single logging configuration for each firewall and may own CloudWatch log groups. `modules/routes` is a temporary adapter that owns only caller-declared `aws_route` resources.

The root accepts a policy ARN and VPC/subnet handles. Public `modules/policy-control` and `modules/rule-groups` own independent policy and rule-group lifecycles; they are never created implicitly by the root. TLS inspection configuration creation, VPC endpoint associations, resource sharing, and Transit Gateway firewall placement are not supported in 2.0. The reserved Transit Gateway input variant fails with an actionable plan error.

The root does not create VPCs, subnets, route tables, KMS keys, S3 buckets, or Firehose delivery streams. These boundaries keep independent AWS lifecycles and blast radii independent.
