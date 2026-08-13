# Frequently asked questions

## Does the root module create a complete inspected VPC?

No. It creates or observes Network Firewall resources and endpoint mappings. VPC
v5 can own the VPC/subnets/route tables, and routes must be composed explicitly.
See [VPC v5 composition](vpc-v5-composition.md).

## Does creating a firewall redirect traffic automatically?

No. Endpoints do not affect traffic until forward and return route tables select
them. Design symmetric same-AZ paths and verify traffic in every AZ.

## Why are firewalls a map when I usually need one?

Caller keys are durable state identity and allow a fabric state to own multiple
independent firewalls when account, Region, owner, release cadence, and failure
domain are intentionally shared. For one firewall, use the stable key `primary`.

## Can I use labels such as `az1` for endpoint keys?

No. Endpoint map keys are real Availability Zone names. They must line up with
subnet and route-table AZ maps. Stable logical aliases are not sufficient for
zonal route selection.

## What happens when an endpoint subnet or address family changes?

AWS replaces the physical endpoint for that firewall/AZ mapping. Treat the
change as a dataplane migration. Prefer blue/green placement and a reviewed
route cutover.

## What does inject mode own?

With `create = false`, the root reads an existing firewall by ARN and publishes
normalized outputs. It does not adopt, update, protect, or delete that firewall.
Injected attachment readiness is operationally verified rather than guaranteed
by a create-resource dependency.

## Which outputs should consumers use?

Use Tier 1 root outputs and named stable submodule outputs. The
`aws_network_firewall` v1 bridge is deprecated and removed in v3. `resources` is
an unsupported provider-shape escape hatch. See [how to use outputs](outputs.md).

## Should I use VPC v5 native routes or `modules/routes`?

Use VPC v5 native routes for route tables owned in the VPC v5 state. Use
`modules/routes` for route tables owned elsewhere that need explicit AZ-local
Network Firewall endpoint routes. Never let both own the same
route-table/destination pair.

## Is `acknowledge_external_route_table = true` an ownership check?

It is an explicit caller assertion, not discovery. Terraform cannot prove no
other state owns the route. Confirm ownership before setting it.

## Can I use `DROP_TO_ALERT` for my Suricata group?

No. AWS supports that override for managed rule groups. A blocking customer group
needs an independently validated alert-only `observation_arn`.

## Does observation mode disable stateless drops?

No. Stateless rule groups remain enforced in observation, selective, enforce,
and incident observation posture.

## Does `expires_at` automatically revert incident control?

No. It is required metadata for external monitoring and operator accountability.
A deliberate Terraform change must return the release to normal posture.

## Does attested validation prove independent review?

No. Terraform validates field shape. Independent assurance requires a separately
produced manifest/digest or signature, immutable validation context, and CI that
recomputes and verifies evidence. See [rule management](rule-management.md).

## Why doesn't Terraform show a SOC content hotfix?

In `content_management = "external"`, Terraform ignores live content after
bootstrap and continues to own structure. The SOC/SOAR release system must record
and verify `UpdateRuleGroup` changes.

## Can policy control discover metadata for an arbitrary ARN?

No. The AWS provider has no rule-group data source suitable for that contract.
Pass `rule_group_records` from `modules/rule-groups`; unmatched external ARNs use
caller-attested metadata.

## Why retain candidate, active, and LKG policies at once?

Immutable releases make promotion and rollback an ARN-binding decision rather
than an in-place structural mutation. The LKG remains available if a new policy
or rule reference causes harm.

## Why does `terraform validate` pass when example IDs are fake?

Validation checks HCL and schemas, not the existence of account-specific
resources. Example values marked as placeholders must be replaced before plan or
apply, and static validation does not prove traffic.

## Why might the Registry quick start fail before a release is published?

The public README shows the canonical Registry source/version. Repository smoke
tests rewrite only the source to the local checkout so documentation can be
validated before publication. Consumers must use an available published version
or a reviewed Git/local source for pre-release evaluation.

## Can I keep v1 root logging and routing arguments?

No. In v2, logging and external-table routes moved to public submodules. Follow
the [2.0 upgrade guide](UPGRADE-GUIDE-2.0.md), rehearse on copied state, and
require a non-destructive approved plan.

## Does the module create S3 buckets or Firehose streams for logs?

No. The logging submodule can create CloudWatch log groups. S3 buckets and
Firehose streams remain external and are referenced by their destination names.

## Should unrelated firewalls share one Terraform state?

Usually not. Share a state only when account, Region, ownership, release cadence,
access control, and failure domain are deliberately shared. Separate states
reduce blast radius for independent environments or teams.
