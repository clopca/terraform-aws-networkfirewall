# Incident control and rollback

## Objective

Reduce harmful stateful policy behavior quickly with the smallest effective
control while preserving visibility, unaffected protections, route symmetry, and
a clear return to normal.

## Prerequisites

- An incident/change identifier, named owner, approver/stop authority, and
  timestamped communication channel.
- Active policy ARN, release key, `effective_releases`, and retained LKG policy
  ARN.
- Healthy ALERT/FLOW logging and applicable TLS telemetry.
- Known positive, negative, management, DNS, identity, and `HOME_NET` probes.
- Customer blocking groups have alert-only observation variants if observation
  may be required.
- Terraform state/backend access and authority to change policy posture or the
  firewall policy ARN.

## Expected plan

Expect one of these, in increasing scope:

1. a policy release with one named stateful slot set to `observe`;
2. a policy release with `incident_control.mode = "observe_all_stateful"`;
3. a firewall policy ARN change to the retained LKG release.

The plan must retain logging, routes, endpoints, rule groups, active evidence,
and all policy releases needed for recovery. Stop on delete, replace, route,
subnet, endpoint, or unrelated resource actions.

## Steps

### 1. Triage without changing visibility

1. Confirm the symptom with service health, application telemetry, ALERT/FLOW
   events, and per-AZ path checks.
2. Identify whether one stateful slot, all stateful behavior, policy structure,
   stateless behavior, routing, or an external dependency is responsible.
3. Keep logging enabled. Do not use logging removal as load shedding.
4. Record the current ARN and posture before changing anything.

### 2. Apply the smallest lever

**One offending stateful group:**

```hcl
incident_control = {
  mode = "normal"
  group_overrides = {
    suspicious_slot = "observe"
  }
  change_id  = "INC-1234"
  owner      = "network-security"
  expires_at = "2026-08-14T03:00:00Z"
}
```

The named slot must exist. Customer blocking content must have an
`observation_arn`; managed groups can use their supported managed override.

**Broad stateful impact:** set `mode = "observe_all_stateful"` with the same
metadata. This does not disable stateless groups.

**Policy structure/reference problem:** bind the firewall to the retained LKG
policy ARN.

### 3. Review and apply

1. Save a plan and confirm it matches exactly one chosen lever.
2. Obtain incident approval appropriate to the impact.
3. Apply and watch attachment/policy status until stable.
4. Run positive, negative, management, DNS, identity, and return-path probes in
   every affected AZ.
5. Record whether harm stopped and which protections remain active.

### 4. Stabilize and recover

1. Keep the temporary posture visible in code and incident records.
2. Alert on `expires_at`; Terraform does not auto-revert it.
3. Produce and validate a corrective immutable rule-group/policy release.
4. Move through observation and selective enforcement before full enforcement
   when risk warrants.
5. Remove incident control in a reviewed plan and close only after the normal
   posture is verified.

## Stop or abort conditions

- The suspected control does not explain the observed traffic.
- Telemetry is unavailable or contradictory.
- The plan changes more than the selected policy lever.
- Required customer observation variants or LKG ARN are unavailable.
- The issue is stateless or routing-related; stateful observation will not fix it.
- Management-path probes fail before apply.
- An AZ attachment or route is unhealthy, making policy diagnosis unreliable.

## Verification

- The effective firewall policy ARN and `effective_releases` match the incident
  decision.
- Harmful traffic behavior falls below the incident threshold.
- Required good traffic and management paths pass in every affected AZ.
- ALERT/FLOW/TLS telemetry continues and shows the expected control effect.
- Stateless protections remain understood and active.
- `change_id`, `owner`, and `expires_at` are recorded and monitored.
- A corrective release and explicit normal-posture action have owners.

## Rollback

If the selected incident control worsens impact:

1. Revert the unhelpful group override.
2. Escalate from group override to `observe_all_stateful` only if evidence shows
   broader stateful impact.
3. Rebind the retained LKG ARN when current policy structure/references are
   untrustworthy.
4. If the issue is routing or endpoint health, restore the previously verified
   symmetric route path instead of changing policy further.
5. Keep logging enabled and document every lever transition and probe result.
