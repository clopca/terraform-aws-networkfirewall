# Documentation

Use the shortest path that matches your task. The root module owns firewall
placement and lifecycle. Add public submodules only for the resources whose
ownership you want in the same Terraform state.

## Learning paths

### Evaluator

1. Read the root [README](../README.md), especially ownership and cost warnings.
2. Review [module composition](architecture/module-composition.md) and
   [zonal traffic flow](architecture/zonal-traffic-flow.md).
3. Compare [`basic`](../examples/basic) with the external-table
   [`complete_routes`](../examples/complete_routes) composition.
4. Run `terraform init -backend=false` and `terraform validate`; these checks do
   not create AWS resources and do not prove dataplane correctness.

### First deployment

1. Confirm the [prerequisites and quick start](../README.md#quick-start).
2. Start with [`basic`](../examples/basic) for firewall placement and
   [`complete_routes`](../examples/complete_routes) for route composition.
3. Read [VPC v5 composition](VPC-V5-COMPOSITION.md) and
   [how to use outputs](how-to-use-outputs.md).
4. Plan both forward and return routes by AZ before applying.
5. Apply in a non-production account, wait for endpoint readiness, and run
   positive and negative traffic probes.

### Production

1. Select a [rule ownership model](rule-management.md) and document one owner per
   structure, content, policy release, logging destination, and route.
2. Use [policy releases and enforcement](policy-releases-and-enforcement.md) for
   candidate, active, and last-known-good policies.
3. Enable ALERT, FLOW, and TLS logging as applicable.
4. Rehearse [promotion](operations/promote-to-enforce.md),
   [incident rollback](operations/incident-control-and-rollback.md), and
   [rule hotfix](operations/rule-hotfix.md) procedures.
5. Monitor service quotas, endpoint health, dropped traffic, logging delivery,
   and temporary-control expiry.

### Operator

1. Start from the [operations index](operations/README.md).
2. Use [troubleshooting](troubleshooting.md) for plan, readiness, routing, and
   policy-control failures.
3. Use Tier 1 and stable submodule outputs from
   [how to use outputs](how-to-use-outputs.md); do not automate against Tier 3
   provider-object shapes.
4. Preserve logs during incidents and use the smallest effective rollback lever.

### Migrator

1. Read the [2.0 upgrade guide](UPGRADE-GUIDE-2.0.md) completely.
2. Rehearse on a copied state and use
   [`migration_pre_v1_routes`](../examples/migration_pre_v1_routes).
3. Run `scripts/check-migration-plan.sh` against a saved plan and exact approved
   action list.
4. Continue only with zero delete or replace actions and expected, explicitly
   approved create, update, or forget actions.
5. Keep the deprecated `aws_network_firewall` bridge only as long as needed; it
   is removed in v3.

## Task index

| Task | Guide |
|---|---|
| Understand module boundaries | [Module composition](architecture/module-composition.md) |
| Design symmetric routing | [Zonal traffic flow](architecture/zonal-traffic-flow.md) |
| Compose AWS IA VPC v5 | [VPC v5 composition](VPC-V5-COMPOSITION.md) |
| Consume stable outputs | [How to use outputs](how-to-use-outputs.md) |
| Choose rule-content ownership | [Rule management](rule-management.md) |
| Promote or roll back a policy | [Policy releases and enforcement](policy-releases-and-enforcement.md) |
| Operate a change or incident | [Operations runbooks](operations/README.md) |
| Diagnose failures | [Troubleshooting](troubleshooting.md) |
| Answer contract questions | [FAQ](faq.md) |
| Upgrade state/configuration | [2.0 upgrade guide](UPGRADE-GUIDE-2.0.md) |
| Review design decisions | [ADR index](adr/README.md) |

## Contract boundaries

- `terraform validate` proves HCL and provider-schema compatibility, not that IDs
  exist, route tables are exclusively owned, traffic is symmetric, or AWS accepts
  Suricata content.
- Endpoint outputs become operationally useful only after the service reports
  healthy attachments for every requested AZ.
- Inject mode observes a firewall through an AWS data source. It does not adopt
  lifecycle ownership.
- The route bridge owns only declared `aws_route` resources; it never discovers,
  imports, or owns route tables.
- Terraform can validate attestation shape but cannot establish that evidence is
  independently produced or trustworthy.
