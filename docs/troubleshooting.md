# Troubleshooting

Start with the first failing boundary: HCL validation, AWS plan, apply/readiness,
routing, logging, or policy behavior. Preserve the plan and exact error before
changing configuration.

## Fast triage

| Symptom | Likely boundary | First checks |
|---|---|---|
| `terraform init` cannot find v2/v5 | Pre-release or wrong source/version | Confirm Registry release availability; for repository validation use the checked-in smoke scripts. |
| `terraform validate` passes but plan fails | Placeholder or account-specific values | Replace example IDs/ARNs; confirm account, Region, VPC, subnet, and policy existence. |
| Firewall creates but traffic bypasses it | Routes are not implicit | Inspect every forward and return route table by AZ. |
| Traffic works in one AZ only | AZ key/target mismatch | Compare route-table AZ set with endpoint IDs by AZ and attachment health. |
| Injected firewall readiness is unverified | Data-source limitation | Check AWS attachment sync/state directly before route cutover. |
| Observation still drops traffic | Customer group lacks observation variant or stateless rule drops | Inspect group kind, `observation_arn`, stateless behavior, and effective release. |
| Temporary posture did not expire | Expected behavior | `expires_at` is metadata; apply an explicit return to normal. |
| Route already exists/conflicts | Multiple owners | Find the state/stack owning the route-table/destination pair; do not duplicate ownership. |
| Content hotfix absent from plan | Dynamic SecOps mode | Verify the external `UpdateRuleGroup` delivery record; post-bootstrap content drift is ignored. |
| README drift guard fails | Generated README stale | Run `terraform-docs .`, review both `.header.md` and generated tables, then rerun `scripts/check-docs.sh`. |

## Initialization and validation

### Registry module not found

The README intentionally shows canonical Registry sources. If a major release is
not published yet, Registry initialization cannot succeed. Repository smoke tests
copy the documented configuration and rewrite only the source/version to a local
checkout or checked-in contract fixture.

Do not change public examples to a sibling worktree path. Such paths fail in CI,
archives, and consumer checkouts.

### Provider schema cannot load

1. Confirm Terraform and platform architecture match the provider package.
2. Run `terraform version` and `terraform providers`.
3. Re-run `terraform init -backend=false -lockfile=readonly` from the exact module
   or example directory.
4. If a local ignored provider cache is damaged, move it aside and initialize
   again without changing `.terraform.lock.hcl`.
5. Do not bypass operating-system execution protections.

### Validation passes with placeholders

`terraform validate` checks syntax and schemas. It usually does not verify that a
VPC, subnet, policy, route table, ARN, or account exists. A successful static
example validation is not permission to apply placeholder values.

## Firewall placement and readiness

### Endpoint subnet validation fails

Confirm:

- each firewall has at least one endpoint subnet;
- caller AZ keys are real AZ names, not labels such as `az1`;
- subnet IDs are unique within the firewall;
- address-family values are supported;
- non-IPv4 or changed address-family mappings have deliberate acknowledgement;
- create-mode fields are absent in inject mode and vice versa.

### Address-family change is blocked

Changing an existing firewall/AZ mapping from IPv4 to dual stack or IPv6 replaces
the physical endpoint. Prefer a blue/green mapping and route cutover. The
acknowledgement must be a literal reviewed `true`; a computed unknown value can
defer validation until apply and must not be treated as an early plan guarantee.

### Injected endpoint reports unverified readiness

Inject mode observes an existing firewall by ARN. The provider data source cannot
provide the same create-resource dependency and attachment guarantee. Verify
`SyncStates`, attachment status, AZ set, and VPC directly in AWS before consuming
the endpoint map.

## Routing

### No traffic after apply

The firewall module does not create routes. Check, in order:

1. workload subnet route to its same-AZ firewall endpoint;
2. firewall subnet route to NAT/TGW/destination;
3. destination or NAT return route to the same-AZ endpoint;
4. endpoint-to-workload CIDR route;
5. NACL/security-group/TGW appliance-mode constraints;
6. policy and stateless default actions;
7. ALERT/FLOW logs for the flow tuple.

### Route points to the wrong endpoint

Compare:

```hcl
module.network_firewall.vpc_endpoint_ids_by_firewall_by_az.primary
```

with the route-table IDs by AZ. Do not derive endpoint choice from list order.
VPC v5 `ids_by_az` requires every AZ in the source group. The route bridge
requires each route's `availability_zone` to exist in its endpoint map.

### Route ownership acknowledgement fails

Set `acknowledge_external_route_table = true` only after confirming the table is
owned outside the route submodule and no other state owns the same destination.
The flag does not import, discover, or override an existing route.

## Rule groups and policy control

### Suricata group is rejected

Check exactly one source lane, capacity, type, STRICT_ORDER action order, required
IP/port sets, SID uniqueness/range, and source-validation fields. Module checks do
not replace AWS parser validation.

### Typed record mismatch

Pass the original map directly:

```hcl
rule_group_records = module.rule_groups.rule_group_records
```

Policy control matches by ARN. A copied record with different kind, rule order,
capacity, or `requires_home_net` is rejected.

### Observation still blocks

- Managed references may use `DROP_TO_ALERT`.
- Customer blocking references need a distinct alert-only `observation_arn`.
- Stateless groups remain enforced in every enforcement mode.
- A named `force_enforce` override intentionally wins over global observation.

Inspect `effective_releases`, not only the requested mode.

### Incident metadata validation fails

Any non-normal incident posture or non-empty group override requires all three:
`change_id`, `owner`, and `expires_at`. Normal posture must not retain stale
incident metadata. Expiry does not trigger an automatic apply.

## Logging

### Duplicate ownership

Only one state should own the effective logging configuration for a firewall.
Multiple caller keys for the same firewall ARN are rejected. Consolidate ALERT,
FLOW, and TLS destinations under one configuration key.

### Destination fails at apply

CloudWatch log groups can be created by the logging submodule. S3 buckets and
Firehose streams are injected by name and remain external; verify existence,
Region, policy/IAM, encryption, and service delivery permissions.

Changing `monitoring_dashboard` can temporarily remove and reinstate all
logging destinations with AWS provider 6.60. Use a change window and verify log
delivery after apply.

## Migration

Never accept a migration plan because it “looks mostly right.” Save the plan and
run:

```shell
./scripts/check-migration-plan.sh migration.tfplan approved-actions.txt
```

The guard rejects delete and replace, and requires exact approval for create,
update, and forget. If it fails, update the migration configuration or approval
from reviewed evidence; do not weaken the guard.
