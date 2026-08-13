# Emergency rule hotfix

## Objective

Deliver one urgent detection or blocking correction with bounded scope,
traceable identity, independent validation, explicit rollback, and later
integration into the normal security release.

## Prerequisites

- Incident/change ticket, owner, approver, affected rule-group slot, and urgency
  are recorded.
- The proposed rule has a unique SID, incremented `rev`, owner, ticket reference,
  and measurable rollback condition.
- Existing group capacity and SID allocation are known.
- ALERT/FLOW logging and match/no-match test paths are available.
- Active and LKG policy/rule-group ARNs are recorded.
- For externally managed content, the SOC/SOAR update-token and evidence process
  is operational.

## Expected plan

Prefer a new versioned rule group using reserved capacity and a new immutable
policy release that changes only the named slot ARN. The old group and policy
remain for rollback.

If dynamic SecOps owns live content, Terraform should show no content change;
the external delivery record must show the exact ARN, update token, bundle
digest, and result. A plan with unrelated policy slots, endpoint, route, logging,
or firewall replacement is unacceptable.

## Steps

### 1. Define the hotfix

Record:

- SID, `rev`, owner, ticket/change ID, and expiry/review date;
- detection/blocking intent and traffic scope;
- exact match and no-match fixtures;
- capacity impact and rule priority/order;
- rollback condition and previous ARN/bundle digest.

Place the hotfix before a terminal `pass` when strict order requires it; a rule
after a terminal pass may never evaluate.

### 2. Build a versioned group

1. Prefer a new caller key/name and retained old group rather than mutating the
   active group in place.
2. Use pre-reserved capacity; capacity changes replace a group and are not an
   incident-time edit.
3. Produce the bundle SHA-256 and independently verifiable manifest evidence.
4. Run Suricata lint/parser checks, AWS validation, duplicate SID checks, and
   targeted match/no-match tests.
5. Start alert-first when the incident permits. Blocking customer content needs
   a corresponding alert-only observation variant for policy observation.

### 3. Bind only the named slot

1. Create a new immutable policy release referencing the hotfix group in the
   intended slot and retaining every other approved reference.
2. Use `force_enforce` only for that named slot when immediate blocking is
   approved and observation would not meet the incident objective.
3. Include `change_id`, `owner`, and `expires_at` for temporary incident control.
4. Save and review the plan; compare `effective_releases` with the active policy.
5. Apply in the smallest environment/scope available, then the affected scope.

### 4. Verify and monitor

1. Run the positive match fixture and confirm the expected ALERT or block.
2. Run no-match, legitimate application, DNS, identity, management, and return
   traffic probes.
3. Check every affected AZ and confirm no unexpected cross-AZ/asymmetric path.
4. Monitor false positives, latency, resets, drops, and logging delivery against
   the rollback condition.
5. Record policy ARN, group ARN, digest, plan/apply, evidence, and timestamps.

### 5. Integrate into normal release

1. Reconcile the hotfix into the normal source bundle and review stream.
2. Re-run the full validation suite, not only targeted incident tests.
3. Publish a normal immutable rule-group and policy release.
4. Remove temporary `force_enforce` or incident metadata deliberately; expiry is
   not automatic.
5. Retire superseded groups only after rollback retention requirements expire.

## Stop or abort conditions

- SID collision, missing `rev`, owner, ticket, or rollback condition.
- Capacity is insufficient or would require in-place replacement during the
  incident.
- Digest/evidence mismatch or AWS/parser validation failure.
- Positive match fails, no-match triggers, or management traffic is affected.
- The plan changes any policy slot besides the named hotfix slot or removes LKG.
- Logging is unavailable or the expected rule is behind a terminal `pass`.
- Required approval for immediate `force_enforce` is absent.

## Verification

- The intended SID/rev fires only on the approved match traffic.
- `effective_releases` shows the exact hotfix ARN in the named slot and no
  unintended reference changes.
- Good traffic and management probes pass in every affected AZ.
- ALERT/FLOW telemetry is healthy and the rollback threshold is monitored.
- Old group/policy ARNs remain available.
- A normal-release integration item has an owner and due date.

## Rollback

1. Rebind the named slot to the prior rule-group ARN through a new/retained policy
   release, or remove its temporary `force_enforce` directive.
2. If the hotfix release is broadly unsafe, rebind the firewall to the LKG policy
   ARN.
3. For dynamic SecOps content, use the recorded previous bundle and a fresh AWS
   update token; never replay a stale token.
4. Verify good/bad traffic and telemetry after rollback.
5. Preserve the failed bundle and evidence for analysis; do not silently overwrite
   the normal release history.
