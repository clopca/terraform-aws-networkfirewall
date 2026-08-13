# ADR 0005: Terraform and AWS provider baseline

## Status

Accepted

## Decision

The module requires Terraform `>= 1.7` and AWS provider `>= 6.59, < 7.0`.

## Verification

The provider floor was verified locally on 2026-08-13 with Terraform 1.15.8 and AWS provider 6.59.0 by running `terraform providers schema -json` and inspecting these schemas:

- `aws_networkfirewall_firewall`: `availability_zone_change_protection`, `enabled_analysis_types`, VPC `subnet_mapping.ip_address_type`, `availability_zone_mapping`, and encryption configuration;
- data source `aws_networkfirewall_firewall`: ARN lookup and `firewall_status.sync_states` attachment status;
- `aws_networkfirewall_logging_configuration`: TLS log destinations and `enable_monitoring_dashboard`;
- `aws_cloudwatch_log_group`: retention and KMS configuration;
- `aws_route`: IPv4, IPv6, prefix-list destinations, and VPC endpoint targets.

6.59 is the lowest version verified for the complete phase-1 contract. The `< 7.0` ceiling prevents an unreviewed provider-major schema change. Lowering the floor requires a checked schema matrix plus the complete test suite; it is not inferred from individual resource release dates.
