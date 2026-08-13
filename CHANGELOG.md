# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Integrated VPC v5, centralized inspection, and existing-firewall examples.
- Learning paths, architecture diagrams, output guidance, operator runbooks,
  troubleshooting, FAQ, and ADR index.
- Generated README drift checks and pre-release Registry quick-start validation.

## [2.0.0] - 2026-08-13

### Added

- Caller-keyed `firewalls` map for one or more independently owned firewalls.
- Stable firewall identity, effective policy, and AZ-keyed endpoint outputs.
- `modules/logging` for one logging configuration per firewall and optional
  CloudWatch log-group ownership.
- `modules/routes` for explicit routes in externally owned route tables.
- `modules/rule-groups` for Terraform, AWS-managed binding, and externally
  managed content boundaries.
- `modules/policy-control` for immutable policy releases, observation/selective/
  enforce posture, and incident controls.
- Delete, policy-change, subnet-change, and Availability-Zone-change protection
  defaults for created firewalls.
- Non-destructive v1/pre-v1 migration chains and saved-plan guard.

### Changed

- The root singleton interface is replaced by `firewalls = map(object(...))`.
- Firewall endpoint identity is keyed by caller-supplied Availability Zone names.
- Logging and routing are explicit submodule compositions rather than root
  concerns.
- Terraform `>= 1.7` and AWS provider `>= 6.59, < 7.0` are required.

### Deprecated

- Root output `aws_network_firewall` is a temporary v1 compatibility bridge. It
  is populated only for a created firewall keyed `primary` and is removed in v3.

### Removed

- v1 root logging and `routing_configuration` interfaces. Use
  `modules/logging` and `modules/routes`.
- Positional/list-derived state identity for public collections.

See the [2.0 upgrade guide](docs/UPGRADE-GUIDE-2.0.md) for configuration and
state migration.

[Unreleased]: https://github.com/aws-ia/terraform-aws-networkfirewall/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/aws-ia/terraform-aws-networkfirewall/compare/v1.0.2...v2.0.0
