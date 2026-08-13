# Policy releases and enforcement

`modules/policy-control` creates or observes immutable policy releases keyed by
caller identity. A firewall binds one selected policy ARN; candidate, active,
and last-known-good (LKG) releases remain independently addressable.

## Release set

Use stable keys that encode release identity and TLS posture, for example:

```hcl
locals {
  active_release = "2026_08_13_plain"
  lkg_release    = "2026_08_01_plain"
}
```

Created policy keys and names must end in `-plain` or `-tls` as required by the
public contract. Changing a key is a new state identity, not an in-place rename.

A release declares STRICT_ORDER stateful references, priorities, capacities,
behavior, enforcement thresholds, optional TLS configuration, and incident
control. Rule content stays in rule groups and is intentionally absent from
`effective_releases`.

## Enforcement modes

| Mode | Result |
|---|---|
| `observation` | Managed references can use `DROP_TO_ALERT`; blocking customer references select `observation_arn`. |
| `selective` | Slots with `enforce_from = "selective"` or `"observation"` enforce; later slots stay observable. |
| `enforce` | All selected references use their enforcement ARNs and behavior. |

Stateless rule groups remain enforced in every mode. Policy posture does not
turn them into alerts.

## Incident-control precedence

For each stateful slot:

1. a named `group_overrides` entry is most specific;
2. incident-wide `observe_all_stateful` applies next;
3. normal `enforcement.mode` and the slot's `enforce_from` threshold apply last.

Temporary incident posture requires `change_id`, `owner`, and `expires_at`.
`expires_at` is metadata for automation and operators; Terraform does not
schedule or auto-revert the control. Monitor expiry outside Terraform and commit
a deliberate return to normal.

## Promotion contract

Before binding a firewall to a candidate release:

- verify bundle and independent validation evidence;
- confirm ALERT/FLOW/TLS logging health;
- review would-drop traffic and false-positive owners;
- test `HOME_NET`, DNS, time sync, identity, and management paths;
- retain an LKG policy ARN;
- verify every requested AZ endpoint is ready;
- run positive and negative probes in observation, selective, and enforce stages.

Use [promote to enforce](operations/promote-to-enforce.md) for the complete
procedure.

## Rollback contract

Prefer the smallest effective lever:

1. override one offending stateful group;
2. set incident-wide `observe_all_stateful` if the issue is broad;
3. bind the firewall to the retained LKG policy ARN if policy structure or
   references are suspect.

Keep logging enabled during diagnosis. Use
[incident control and rollback](operations/incident-control-and-rollback.md).
