# Rule management

Choose one content owner per rule group. Terraform always owns the structural
identity of a group created by `modules/rule-groups`; content ownership depends
on `content_management` and the source lane.

## Model 1: IaC pure

Set `content_management = "terraform"` (the default). Terraform owns group
structure and content. Content drift appears in a plan and is corrected on
apply.

Use this model when:

- rule changes follow infrastructure review and release cadence;
- the complete content can be reviewed safely in source control;
- AWS-side emergency edits are prohibited or deliberately short-lived.

A created group must select exactly one source lane: Suricata `rules_string`,
domain list, native stateful rules, or native stateless rules. Typed variables,
required sets, capacity, rule order, and SID-range checks reject many structural
errors, but AWS is still the authoritative parser for Suricata semantics.

## Model 2: AWS managed

AWS owns changing content. Terraform binds a managed rule-group ARN and the
caller supplies policy metadata that the provider cannot discover through a
rule-group data source.

Use this model when AWS Managed Rules supply the desired threat intelligence.
`DROP_TO_ALERT` policy overrides are available only for managed references. The
module rejects attempts to apply that managed-only override to customer groups.

The caller remains responsible for declaring and reviewing:

- `kind = "managed"`;
- STRICT_ORDER compatibility;
- capacity used for policy quota checks;
- priority and behavior metadata;
- whether the managed group requires `HOME_NET` behavior in the surrounding
  policy design.

## Model 3: Dynamic SecOps

Set `content_management = "external"`. Terraform owns group identity, capacity,
sets, encryption, tags, and bootstrap seed content. SOC/SOAR owns live content
after creation through `UpdateRuleGroup`. Terraform ignores post-bootstrap
content drift but continues to plan structural drift.

Use this model when IOC/signature updates must move faster than infrastructure
releases and an independently controlled delivery system exists.

Requirements:

1. Reserve sufficient capacity; capacity changes replace a rule group.
2. Seed valid content for creation.
3. Restrict `UpdateRuleGroup` permissions to the external delivery role.
4. Record bundle identity, digest, rule-group ARN, AWS update token, operator,
   and change/ticket in the external release system.
5. Validate match and no-match traffic and monitor ALERT/FLOW telemetry.
6. Define how emergency content is reconciled into the normal release stream.

Do not set attested source validation for external-content mode; the module
rejects that combination because Terraform no longer controls live content.

## Attestation honesty

`source_validation.mode = "attested"` validates only the shape of evidence. It
cannot prove the manifest is independent, that a digest was calculated by a
trusted system, or that a reviewer inspected the content.

A stronger release produces and verifies:

- a separate manifest URI with its own digest or signature;
- the exact rule bundle SHA-256;
- validation job identity and immutable commit/build reference;
- AWS account, Region, engine version/context, capacity, and rule order;
- parser/lint results plus match and no-match tests;
- approval and rollback metadata.

CI should retrieve independently published evidence, recompute the bundle digest,
verify the manifest signature/digest, and reject mismatches. Do not generate both
the bundle and its “independent” attestation in the same unchecked job.

## Typed policy composition

Pass the complete record map to policy control:

```hcl
module "policy_control" {
  source = "./modules/policy-control"

  rule_group_records = module.rule_groups.rule_group_records
  policies           = local.policy_releases
}
```

Policy control matches records by ARN, propagates `requires_home_net`, and
validates declared kind, rule order, and capacity. An injected ARN without a
matching record remains a caller attestation; Terraform does not remotely
discover its metadata.

## Observation and enforcement variants

Managed groups can use `DROP_TO_ALERT` in observation mode. Customer groups
whose content blocks traffic need a separate alert-only `observation_arn`.
Observation mode is not a universal semantic rewrite of arbitrary customer
rules.

For customer groups:

- keep enforcement and observation groups versioned together;
- reserve equal or reviewed capacity;
- ensure the observation variant preserves visibility without terminal blocking;
- test both variants against positive and negative traffic;
- include both ARNs in release evidence.

## Ownership decision table

| Question | IaC pure | AWS managed | Dynamic SecOps |
|---|---|---|---|
| Who changes live content? | Terraform release | AWS | SOC/SOAR pipeline |
| Does content drift appear in Terraform? | Yes | Not applicable | No after bootstrap |
| Can policy use `DROP_TO_ALERT`? | No | Yes | No |
| Needs customer observation variant? | For blocking content | No | For blocking content |
| Independent evidence needed? | Strongly recommended | Review AWS release/metadata | Required for the external delivery control |

See [rule-management models](architecture/rule-management-models.md),
[`rule_groups_suricata`](../examples/rule_groups_suricata), and
[rule hotfix](operations/rule-hotfix.md).
