# Network Firewall module documentation

Use these guides to choose and compose the v2 contracts. The root
[README](../README.md) remains the starting point for installation, the quick
start, cost guidance, and example selection.

## Contract guides

| Guide | Use it for |
| --- | --- |
| [VPC v5 composition](vpc-v5-composition.md) | Firewall subnet placement, AZ-local endpoints, native VPC v5 routes, external route tables, symmetric forward and return paths, and readiness. |
| [Rule management](rule-management.md) | Terraform-owned, AWS-managed, and dynamic SecOps rule groups; source lanes; typed sets; evidence; and policy composition. |
| [Policy control](policy-control.md) | Immutable policy releases, observation/selective/enforce behavior, managed and customer group differences, incident overrides, and rollback. |
| [Security and operations](security-and-operations.md) | Firewall protections, logging ownership, readiness, monitoring, change controls, and the operational runbook map. |
| [Outputs](outputs.md) | Stable Tier 1 composition, the temporary Tier 2 v1 bridge, submodule handles, and the Tier 3 escape hatch. |
| [Troubleshooting](troubleshooting.md) | Initialization, placement, readiness, routing, rule, policy, logging, and migration failures. |
| [FAQ](faq.md) | Short answers about ownership, endpoint identity, observation behavior, outputs, and validation boundaries. |

## Input and module map

Start in the guide named in the final column, then use the generated input tables
in the root and submodule READMEs for complete types and defaults.

| Surface | Responsibility | Guide |
| --- | --- | --- |
| Root `firewalls` | Create or inject firewalls, define VPC endpoint placement, protections, policy binding, encryption, analysis options, and tags. | [VPC v5 composition](vpc-v5-composition.md) |
| `modules/logging.logging_configurations` | Own one effective logging configuration per firewall and optionally CloudWatch log groups. | [Security and operations](security-and-operations.md) |
| `modules/routes.vpc_endpoint_ids_by_az` | Supply the stable AZ-keyed endpoint target map for external route tables. | [VPC v5 composition](vpc-v5-composition.md) |
| `modules/routes.routes` | Own only caller-declared `aws_route` resources in external tables. | [VPC v5 composition](vpc-v5-composition.md) |
| `modules/rule-groups.rule_groups` | Create or inject typed rule-group releases and select Terraform or external content ownership. | [Rule management](rule-management.md) |
| `modules/policy-control.rule_group_records` | Consume typed identity and ownership metadata from the rule-group module. | [Rule management](rule-management.md) |
| `modules/policy-control.policies` | Create or inject immutable policy releases and compile enforcement/incident posture. | [Policy control](policy-control.md) |

## Choose a task

| Task | Start here |
| --- | --- |
| Place a firewall in VPC v5 subnets | [Placement contract](vpc-v5-composition.md#firewall-placement) |
| Route each table to the endpoint in its AZ | [Native VPC v5 routes](vpc-v5-composition.md#native-vpc-v5-routes) or [external route tables](vpc-v5-composition.md#external-route-table-bridge) |
| Validate a symmetric egress or TGW path | [Forward and return routing](vpc-v5-composition.md#forward-and-return-routing) |
| Choose who owns live rule content | [Rule-content ownership models](rule-management.md#rule-content-ownership-models) |
| Pass rule metadata into a policy safely | [Typed policy composition](rule-management.md#typed-policy-composition) |
| Promote candidate to active or roll back | [Policy release roles](policy-control.md#policy-release-roles) |
| Use incident observation controls | [Incident-control precedence](policy-control.md#incident-control-precedence) |
| Configure ALERT, FLOW, or TLS logs | [Logging ownership](security-and-operations.md#logging-ownership) |
| Consume endpoint readiness safely | [Endpoint records](outputs.md#endpoint-records-and-readiness) |
| Migrate v1 or pre-v1 state | [Upgrade guide 2.0](UPGRADE-GUIDE-2.0.md) |

## Operations

The [operations index](operations/README.md) selects the runbook for the active
change:

- [Promote to enforce](operations/promote-to-enforce.md) moves a validated
  candidate through observation and selective enforcement while retaining LKG.
- [Incident control and rollback](operations/incident-control-and-rollback.md)
  applies the smallest effective group, stateful-wide, or policy-ARN rollback.
- [Emergency rule hotfix](operations/rule-hotfix.md) publishes a bounded,
  versioned rule change and integrates it into the normal release afterward.

Use the [security and operations guide](security-and-operations.md) for the
shared prerequisites: protections, attachment readiness, logging health,
monitoring, plan review, and temporary-control expiry.

## Upgrade and migration

- [Upgrade guide 2.0](UPGRADE-GUIDE-2.0.md) is the sequential v1-to-v2 runbook,
  including state moves, approval files, plan gates, stop conditions, and
  verification.
- [Historical 1.0 upgrade guide](UPGRADE-GUIDE-1.0.md) records the older route
  transition needed by some pre-v1 states.
- [`migration_pre_v1_routes`](../examples/migration_pre_v1_routes) provides the
  complete twelve-route move catalog for copied-state rehearsal.
- [ADR index](adr/README.md) records accepted boundaries and the one reserved,
  unimplemented endpoint-association shape.

## Examples

The root [example catalog](../README.md#examples) compares all ten configurations
by purpose, ownership, prerequisite, and validation boundary. Each example
README follows the same structure: real contract keys, a literal differential
configuration excerpt, prerequisites and cost when relevant, run commands, and
a scenario-specific runtime check.

Start with [`basic`](../examples/basic) for an existing VPC and policy,
[`end_to_end_vpc_v5`](../examples/end_to_end_vpc_v5) for the integrated path,
or [`inject_existing_firewall`](../examples/inject_existing_firewall) when
firewall lifecycle remains external.

## Repository policies

- [Contributing](../CONTRIBUTING.md) documents the complete validation commands
  and public-contract review requirements.
- [Security policy](../SECURITY.md) defines private vulnerability reporting and
  sensitive-data handling.
- [Changelog](../CHANGELOG.md) records release-level additions, changes,
  deprecations, and removals.
