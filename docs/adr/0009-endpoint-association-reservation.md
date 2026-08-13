# ADR 0009: Reserved VPC endpoint association shape

## Status

Reserved for phase 3

## Decision

The phase-3 VPC endpoint association contract will not place a map of subnets beneath one association. AWS and provider 6.60 permit exactly one `SubnetMapping` per `aws_networkfirewall_vpc_endpoint_association`; the earlier one-association-to-many-subnets shape is not implementable.

The corrected expansion is one association resource per subnet and AZ, addressed as:

```text
aws_networkfirewall_vpc_endpoint_association.this["<association-key>/<az-key>"]
```

The caller owns `association-key`; the second segment is an AZ name within the consuming account, with AZ ID retained in records for cross-account coordination. `/` remains forbidden inside either caller key so the composite identity is unambiguous.

`firewall_arn`, `vpc_id`, `description`, and the complete subnet mapping are replacement identity in provider 6.60. In particular, editing `description` replaces the physical endpoint. Tags are mutable. Inject mode must provide one association ARN and endpoint ID per AZ because the provider has no data source that can reconstruct this collection.
