# Policy control

`modules/policy-control` creates or observes immutable firewall-policy releases
and compiles each stateful slot into an effective ARN and override. It owns
policy structure and posture, never rule content. A firewall release is selected
by binding one policy ARN from `policy_arns`.

## Policy release identity

`policies` is keyed by caller-owned immutable release identity:

```hcl
policies = {
  candidate-2026-08-13-plain = {
    name        = "inspection-candidate-2026-08-13-plain"
    enforcement = { mode = "observation" }
    # References omitted.
  }
}
```

Created keys and names end in `-plain` or `-tls`; TLS presence must agree with the
suffix. The key controls Terraform state identity. Create a new key for a new
release rather than renaming or mutating an active identity.

Create mode owns `aws_networkfirewall_firewall_policy`. Inject mode uses
`create = false`, an ARN, and metadata that declares STRICT_ORDER and TLS
presence. The provider does not remotely establish all metadata required by this
contract, so injected values remain caller attestations.

## Policy release roles

Keep at least three independently addressable roles:

| Role | Purpose | Normal posture |
| --- | --- | --- |
| Candidate | Validate the next reference set and expected would-drop behavior. | `observation` |
| Active | Serve the currently approved production policy. | `selective` or `enforce` |
| Last known good | Preserve a tested policy ARN for structural rollback. | Previously approved `enforce` posture |

```hcl
locals {
  candidate_release = "candidate-2026-08-13-plain"
  active_release    = "active-2026-08-12-plain"
  lkg_release       = "last-known-good-2026-08-11-plain"

  selected_policy_arn =
    module.policy_control.policy_arns[local.active_release]
}
```

Retain the LKG resource and all referenced rule groups until rollback retention
ends. Deleting the old policy before the new release is proven removes the
fastest structural rollback.

## Stateful slot contract

Each stateful slot declares one enforcement ARN and the metadata needed to
validate and compile policy behavior:

```hcl
stateful_rule_groups = {
  customer-egress = {
    arn               = var.customer_enforcement_arn
    observation_arn   = var.customer_observation_arn
    priority          = 200
    kind              = "customer"
    rule_order        = "STRICT_ORDER"
    declared_capacity = 500
    enforce_from      = "selective"
    requires_home_net = true
    behavior = {
      actions             = ["alert", "drop"]
      has_terminal_action = false
      override_coverage   = "all_blocking"
    }
  }
}
```

Priorities are unique and bounded. Declared capacities are summed against
service quotas. Every reference must be STRICT_ORDER, and behavior metadata must
agree with the declared action set and terminal-action status.

Pass `rule_group_records` from `modules/rule-groups` to make ARN-matched metadata
authoritative:

```hcl
rule_group_records = module.rule_groups.rule_group_records
```

The module propagates `requires_home_net` and rejects copied kind, rule-order, or
capacity metadata that conflicts with the matching record. An unmatched ARN is
still allowed when the caller intentionally attests its metadata.

## Enforcement modes

The release-level mode and slot-level `enforce_from` threshold compile the
effective reference:

| Mode | Effective behavior |
| --- | --- |
| `observation` | Managed groups may receive `DROP_TO_ALERT`; blocking customer groups select `observation_arn`. |
| `selective` | Slots whose `enforce_from` threshold is `observation` or `selective` use enforcement ARNs; later slots remain observable. |
| `enforce` | Every slot uses its enforcement ARN and blocking behavior. |

Managed and customer groups are intentionally different. AWS supports
`DROP_TO_ALERT` only for managed references. A customer group with blocking
content must provide a separately validated alert-only `observation_arn` whenever
its effective posture can be observation.

Stateless rule groups remain enforced in every mode. Their slot declares a
priority, capacity, and `always_enforced = true`; observation is not a global
firewall bypass.

## Incident-control precedence

Incident controls are compiled per named stateful slot in this order:

1. `group_overrides[slot]` is most specific;
2. `incident_control.mode = "observe_all_stateful"` applies next;
3. normal release mode and the slot's `enforce_from` threshold apply last.

Valid group directives are `observe` and `force_enforce`:

```hcl
incident_control = {
  mode = "observe_all_stateful"
  group_overrides = {
    customer-egress = "force_enforce"
  }
  change_id  = "INC-12345"
  owner      = "network-security-oncall"
  expires_at = "2026-08-14T03:00:00Z"
}
```

Any non-normal mode or non-empty override map requires `change_id`, `owner`, and
`expires_at`. The timestamp is metadata for monitoring and accountability;
Terraform does not schedule or automatically apply a return to normal. Normal
posture must remove stale incident metadata.

Use the smallest effective lever:

- `observe` one slot when one rule group causes harm;
- `observe_all_stateful` when broad stateful behavior is suspect;
- rebind the firewall to the retained LKG policy ARN when policy structure,
  priorities, or references are suspect.

Keep ALERT/FLOW logging enabled during every lever change.

## HOME_NET and engine options

A release that references any group with `requires_home_net = true` must supply
`home_net_cidrs`:

```hcl
home_net_cidrs = ["10.0.0.0/8", "192.168.0.0/16"]
```

Review HOME_NET as a security boundary. Missing workload, management, shared
service, or hybrid prefixes can change stateful rule interpretation even when the
rule bundle is unchanged.

`stream_exception_policy` and `tcp_idle_timeout_seconds` are release-level engine
settings. Treat either change as policy behavior, not harmless metadata. Validate
long-lived sessions, reset behavior, and expected exception handling before
promotion.

## TLS release identity

A TLS release supplies the inspection configuration ARN and session-holding
choice:

```hcl
tls = {
  inspection_configuration_arn = var.tls_inspection_configuration_arn
  enable_session_holding       = true
}
```

TLS presence changes the release identity and must use a `-tls` key/name. Keep
plain and TLS policies as separate immutable releases; do not introduce TLS by
mutating a `-plain` release. Certificate, decryption, excluded-domain, and privacy
controls remain external to this module.

## Promotion contract

Before binding a firewall to a candidate ARN:

1. verify rule-bundle digest and independent validation evidence;
2. compare `effective_releases[candidate]` with the approved reference set,
   priorities, capacities, ARNs, and overrides;
3. confirm ALERT, FLOW, and applicable TLS logging health;
4. review would-drop traffic and false-positive ownership;
5. test HOME_NET, DNS, identity, time, monitoring, and management paths;
6. verify every requested firewall endpoint AZ is ready;
7. retain and record the LKG policy ARN;
8. observe, enforce selected slots, and then enforce broadly only after each
   interval passes its stop thresholds.

The full sequence and stop conditions are in
[promote to enforce](operations/promote-to-enforce.md).

## Rollback contract

When a release causes harm:

1. identify whether one stateful slot, all stateful behavior, stateless behavior,
   policy structure, routing, or endpoint health is responsible;
2. apply the smallest effective stateful control only when stateful policy is the
   cause;
3. bind the LKG ARN when structural policy metadata is untrustworthy;
4. keep logging active and repeat positive, negative, management, and return-path
   probes in every affected AZ;
5. publish a corrective immutable release and deliberately remove temporary
   incident metadata.

The incident procedure is in
[incident control and rollback](operations/incident-control-and-rollback.md).

## Inspect effective outputs

`policy_arns` is the binding contract. `effective_releases` is the inspection
contract:

```hcl
output "release_evidence" {
  value = {
    candidate_arn = module.policy_control.policy_arns[local.candidate_release]
    candidate     = module.policy_control.effective_releases[local.candidate_release]
    active_arn    = module.policy_control.policy_arns[local.active_release]
    active        = module.policy_control.effective_releases[local.active_release]
    lkg_arn       = module.policy_control.policy_arns[local.lkg_release]
  }
}
```

The effective output intentionally omits rule content. Policy control proves
which ARNs and overrides it compiled, not the content currently served by an
AWS-managed or externally managed rule group.

## Policy checklist

- Use immutable `-plain` or `-tls` release keys.
- Retain candidate, active, and LKG ARNs simultaneously.
- Pass typed rule-group records and keep metadata coherent.
- Supply alert-only customer observation variants for blocking groups.
- Treat stateless references as always enforced.
- Require complete incident metadata and monitor expiry externally.
- Review HOME_NET, engine options, TLS presence, capacities, and priorities.
- Verify `effective_releases` before binding a firewall.
