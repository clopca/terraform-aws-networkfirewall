# Operations runbooks

These runbooks assume immutable policy releases, retained last-known-good (LKG)
ARNs, healthy logging, and a change record. Adapt names, commands, approvals, and
monitoring links to your environment before an incident.

| Runbook | Use it when | Primary control |
|---|---|---|
| [Promote to enforce](promote-to-enforce.md) | A validated candidate must move from observation through selective enforcement. | `enforcement.mode` and firewall policy ARN |
| [Incident control and rollback](incident-control-and-rollback.md) | Active policy behavior is harming traffic or availability. | Group override, `observe_all_stateful`, or LKG ARN |
| [Rule hotfix](rule-hotfix.md) | One urgent detection or blocking rule must change ahead of the normal release. | New versioned group and named-slot policy override/release |

## Shared safety rules

- Keep ALERT, FLOW, and applicable TLS logging enabled during changes and
  incidents.
- Confirm all requested AZ attachments are healthy before route or policy
  cutover.
- Preserve stateless behavior awareness: incident observation controls do not
  disable stateless rule groups.
- For temporary incident posture, record `change_id`, `owner`, and `expires_at`.
  Expiry is not automatic.
- Prefer the smallest effective lever and retain a tested rollback for every
  forward step.
- Stop when evidence conflicts, expected plan shape changes, management traffic
  is at risk, or telemetry becomes unavailable.
