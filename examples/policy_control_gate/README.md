# Policy release and incident-control gate

This example creates observation candidate, selective active, enforced
last-known-good, and incident policy releases from the same declared rule-group
set. Use it to promote immutable policy ARNs while preserving a rollback target
and a bounded emergency posture.

## What this demonstrates

- `policies.candidate-2026-08-13-plain.enforcement.mode = "observation"` keeps
  eligible stateful references observable.
- `policies.active-2026-08-12-plain.enforcement.mode = "selective"` enforces
  slots whose `enforce_from` threshold has been reached.
- `policies.last-known-good-2026-08-11-plain` retains an enforced rollback ARN.
- `common_groups.managed-threats.kind = "managed"` permits managed-only
  `DROP_TO_ALERT` behavior when observation is effective.
- `common_groups.customer-egress.observation_arn` supplies an independently
  validated alert-only customer variant.
- `incident_control.mode = "observe_all_stateful"` observes all eligible
  stateful slots while `group_overrides.customer-egress = "force_enforce"`
  keeps one named slot enforced.
- `change_id`, `owner`, and `expires_at` record temporary-control accountability;
  expiry does not trigger an automatic revert.

The firewall binds exactly one policy ARN. Forward and return traffic use that
same selected release; ALERT and FLOW telemetry provide promotion evidence.

## Relevant configuration

The complete deployable configuration is in [`main.tf`](./main.tf). The incident
release is the distinguishing portion:

```hcl
incident-2026-08-13-plain = {
  name                 = "inspection-incident-2026-08-13-plain"
  enforcement          = { mode = "enforce" }
  home_net_cidrs       = ["10.0.0.0/8", "192.168.0.0/16"]
  stateful_rule_groups = local.common_groups
  incident_control = {
    mode            = "observe_all_stateful"
    group_overrides = { customer-egress = "force_enforce" }
    change_id       = "INC-12345"
    owner           = "network-security-oncall"
    expires_at      = "2026-08-14T03:00:00Z"
  }
}
```

## Prerequisites and cost

- Replace the managed and customer ARNs with real, reviewed rule-group releases.
- Validate the customer observation variant independently from enforcement
  content.
- Keep ALERT/FLOW logging healthy and record the active and LKG ARNs.
- Applying creates four firewall policies and can incur policy-associated
  service charges; this example creates no firewall endpoints.

## Run

```shell
terraform init
terraform validate
terraform plan -out=tfplan
```

Review `effective_releases`, exercise both traffic directions, and verify the
rollback ARN before binding a firewall. Static validation cannot verify ARN
existence, attested metadata, or traffic behavior.
