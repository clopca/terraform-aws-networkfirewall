# Rule management

Rule-group structure, live content, validation evidence, and policy binding have
separate owners. `modules/rule-groups` makes those boundaries explicit and
publishes typed records for `modules/policy-control`; it does not turn Terraform
into an independent rule-validation authority.

## Rule-group identity and lifecycle

`rule_groups` is keyed by caller-owned release identity:

```hcl
rule_groups = {
  egress-v1 = {
    name       = "inspection-egress-v1"
    type       = "STATEFUL"
    capacity   = 500
    rule_order = "STRICT_ORDER"
    # Source and validation omitted.
  }
}
```

The key controls Terraform addresses. The name, ARN, bundle digest, and provider
update token are values. Preserve a deployed key or add caller-root `moved`
blocks; do not encode state identity from an ARN or map iteration order.

Capacity is structural and replacement-sensitive. Reserve capacity before an
urgent content release. Rule order and type must remain coherent with every
policy reference.

Create and inject modes are distinct:

- create mode owns the rule-group resource and requires name, type, capacity,
  source metadata, and one content-ownership model;
- inject mode uses `create = false` plus an ARN and caller-declared metadata,
  because the AWS provider does not expose a rule-group data source that can
  establish the required policy contract;
- injected metadata is an attestation by the caller, not remote discovery.

## Closed source lanes

A created group selects exactly one source lane.

| Lane | Intended content | Key fields |
| --- | --- | --- |
| Suricata string | Stateful Suricata rules | `source.rules_string`, optional typed sets and SID range |
| Rules source list | Stateful domain or IP lists | `source.rules_source_list.generated_rules_type`, `target_types`, and `targets` |
| Native stateful | Provider-typed stateful rules | `source.stateful_rules` keyed by caller identity |
| Native stateless | Provider-typed stateless rules | `source.stateless_rules` with unique priorities |

The module rejects multiple lanes, type/lane mismatches, invalid STRICT_ORDER
action ordering, missing required sets, duplicate known SIDs, known SID-range
violations, duplicate stateless priorities, and invalid encryption combinations.
AWS remains authoritative for complete Suricata parsing and service acceptance.

Typed sets keep environment values out of a reusable Suricata bundle:

```hcl
source = {
  rules_string = file("${path.module}/egress.rules")
}

ip_sets = {
  WORKLOADS = ["10.0.0.0/8"]
}
port_sets = {
  WEB_PORTS = ["80", "443"]
}
required_ip_sets   = ["WORKLOADS"]
required_port_sets = ["WEB_PORTS"]
requires_home_net  = true
sid_range          = { min = 4100000, max = 4100099 }
```

`required_ip_sets` and `required_port_sets` validate that referenced bindings are
present and non-empty. `requires_home_net` is exported through the typed record
and lets policy control require `home_net_cidrs` without a second manual flag.

## Rule-content ownership models

### Terraform-owned content

`content_management = "terraform"` is the default. Terraform owns structure and
content, so a changed bundle appears in the plan and apply restores drift.

Use this model when content follows infrastructure review and release cadence,
the full bundle can be stored and reviewed safely, and AWS-side edits are either
prohibited or short-lived emergency actions.

```hcl
rule_groups = {
  egress-v1 = {
    content_management = "terraform"
    # Structural fields omitted.
    source = {
      rules_string = file("${path.module}/egress.rules")
    }
  }
}
```

### AWS-managed content

AWS owns live content for AWS Managed Rules. Terraform does not create the group;
policy control binds a managed ARN plus caller-declared kind, rule order,
capacity, priority, and behavior metadata.

`DROP_TO_ALERT` is valid only for managed references. Do not use it as a general
observation mechanism for customer Suricata groups.

### Dynamic SecOps content

`content_management = "external"` creates structural identity and seed content,
then ignores post-bootstrap content changes. A restricted SOC/SOAR role owns live
updates through `UpdateRuleGroup`.

```hcl
rule_groups = {
  ioc-feed-v1 = {
    name               = "inspection-ioc-feed-v1"
    type               = "STATEFUL"
    capacity           = 1000
    rule_order         = "STRICT_ORDER"
    content_management = "external"
    source = {
      rules_string = file("${path.module}/seed.rules")
    }
  }
}
```

The external delivery system must record the group ARN, bundle identity and
digest, AWS update token, account, Region, operator, change reference, and
result. It must also retain a rollback bundle and obtain a fresh update token for
every update. Terraform continues to plan structural changes such as capacity,
sets, encryption, and tags.

Do not combine external content management with Terraform attestation fields.
The module rejects that contract because Terraform no longer controls the live
bundle whose digest would be asserted.

## Validation evidence

`source_validation.mode = "attested"` validates field shape only:

```hcl
source_validation = {
  mode          = "attested"
  manifest_uri  = "s3://security-evidence/egress-v1/manifest.json"
  bundle_sha256 = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
}
```

A trustworthy release independently produces and verifies:

- the exact rule-bundle SHA-256;
- a separately published manifest with its own digest or signature;
- immutable validation job and commit/build identity;
- AWS account, Region, engine context, capacity, type, and rule order;
- Suricata lint and AWS parser results;
- match, no-match, forward-flow, and reverse-flow tests;
- owner, approval, rollback bundle, and release timestamp.

CI should retrieve the evidence, recompute the bundle digest, verify the
manifest signature or digest, and reject mismatches. A job that generates both
the bundle and its unchecked “independent” evidence does not establish
independence.

## Typed policy composition

Pass records directly to policy control:

```hcl
module "policy_control" {
  source = "./modules/policy-control"

  rule_group_records = module.rule_groups.rule_group_records
  policies           = local.policy_releases
}
```

Each record contains the effective ARN, type, rule order, declared capacity,
kind, content-management mode, HOME_NET requirement, and validation mode.
Policy control matches by ARN, propagates `requires_home_net`, and rejects a
policy slot whose copied kind, order, or capacity conflicts with the record.

Unmatched external ARNs remain caller attestations. Use them only when a separate
control verifies the declared metadata.

## Customer observation variants

Managed references can use `DROP_TO_ALERT`. A customer group whose enforcement
bundle contains blocking actions needs a separate alert-only `observation_arn`:

```hcl
stateful_rule_groups = {
  customer-egress = {
    arn               = var.enforcement_arn
    observation_arn   = var.observation_arn
    kind              = "customer"
    rule_order        = "STRICT_ORDER"
    declared_capacity = 500
    priority          = 200
    enforce_from      = "selective"
    behavior = {
      actions             = ["alert", "drop"]
      has_terminal_action = false
      override_coverage   = "all_blocking"
    }
  }
}
```

Version the enforcement and observation groups together, validate both bundles,
and retain both ARNs in release evidence. Observation is a deliberate content
variant, not a semantic rewrite of arbitrary customer rules.

## Ownership matrix

| Responsibility | Terraform-owned | AWS managed | Dynamic SecOps |
| --- | --- | --- | --- |
| Structural identity | Terraform | External ARN plus declared metadata | Terraform |
| Live content changes | Terraform apply | AWS | SOC/SOAR `UpdateRuleGroup` |
| Content drift in plan | Yes | Not applicable | Ignored after bootstrap |
| Managed `DROP_TO_ALERT` | No | Yes | No |
| Customer observation variant | Required for blocking content | No | Required for blocking content |
| Independent evidence | Strongly recommended | Review AWS release and declared metadata | Required by the external delivery control |

## Release checklist

- Preserve rule-group release keys and reserve capacity before content urgency.
- Select exactly one source lane and one live-content owner.
- Keep typed sets, SID ranges, type, and STRICT_ORDER metadata coherent.
- Validate bundle digest, manifest integrity, AWS parser, and match/no-match flows.
- Pass `rule_group_records` directly into policy control.
- Publish a customer observation variant for every blocking customer group that
  can enter observation posture.
- Retain the previous bundle, ARN, and policy release until rollback retention
  expires.
