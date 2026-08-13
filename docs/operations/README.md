# Operations runbooks

Use these runbooks for policy promotion, incident rollback, and urgent rule
changes. The shared security, logging, readiness, plan-review, and evidence
requirements are in [Security and operations](../security-and-operations.md).
Adapt account-specific approvals, commands, thresholds, and monitoring links
before using a runbook in production.

## Choose the runbook

| Runbook | Use it for | Primary contract |
| --- | --- | --- |
| [Promote to enforce](promote-to-enforce.md) | Moving a validated candidate through observation and selective enforcement while retaining LKG | `policies[*].enforcement.mode` and the selected `policy_arns` value |
| [Incident control and rollback](incident-control-and-rollback.md) | Reducing harmful stateful behavior or returning to a retained policy release | `group_overrides`, `incident_control.mode`, or the firewall `policy_arn` |
| [Emergency rule hotfix](rule-hotfix.md) | Publishing one urgent versioned detection or blocking correction | A new rule-group ARN, named policy slot, and optional `force_enforce` directive |

## Shared operating contract

Every runbook preserves these controls:

- ALERT and FLOW logging remain enabled; TLS logging remains enabled when TLS
  inspection is active.
- Every requested endpoint AZ is healthy before route or policy cutover.
- Positive, negative, management, DNS, identity, and return-path probes have
  explicit expected results.
- Candidate, active, and last-known-good policy/rule releases remain addressable
  through the rollback interval.
- Stateless rule groups remain enforced during stateful observation.
- Blocking customer groups have independently validated alert-only observation
  variants.
- Temporary incident posture records `change_id`, `owner`, and `expires_at`.
  Expiry is monitored externally and does not apply an automatic revert.
- The saved plan contains only the intended release, binding, or incident-control
  change.

Stop when telemetry is unavailable, a requested AZ is unhealthy, the plan
contains an unrelated replacement or deletion, the LKG is absent, or a required
management path fails.

## Evidence to retain

Record the policy and rule-group ARNs, bundle and manifest digests, Terraform
plan, apply result, effective release output, endpoint status by AZ, probe
results, logging links, owner, approver, timestamps, stop decision, and rollback
result. The runbook-specific verification section defines the minimum evidence
for completion.
