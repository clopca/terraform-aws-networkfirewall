# Promote a policy to enforce

## Objective

Move a validated candidate policy from observation through selective enforcement
to full enforcement while preserving symmetric traffic, management access,
telemetry, and an immediately usable LKG rollback.

## Prerequisites

- Candidate policy ARN, release key, bundle SHA-256, and independent validation
  evidence are immutable and reviewed.
- Rule-group metadata, capacities, priorities, behavior, `HOME_NET`, and TLS
  presence match the candidate evidence.
- Blocking customer groups have validated alert-only `observation_arn` variants.
- ALERT and FLOW logs are healthy; TLS logs are healthy when TLS inspection is
  used.
- “Would drop” traffic has owners, expected dispositions, and reviewed false
  positives.
- DNS, identity, time sync, monitoring, automation, and operator management paths
  have explicit probes.
- Every requested AZ attachment is ready and routes are symmetric by AZ.
- The active and retained LKG policy ARNs are recorded and have recent rollback
  verification.
- Change window, owner, approver, stop authority, observation durations, and
  rollback thresholds are recorded.

## Expected plan

At each step, expect only the intended immutable policy release creation and/or
firewall policy ARN update. Existing LKG policy resources remain present.

Stop if the plan contains firewall replacement, endpoint/subnet changes, route
changes, rule-group replacement, deletion of an active/LKG release, unrelated
logging changes, or unreviewed content drift.

## Steps

### 1. Validate the candidate

1. Recompute the rule-bundle digest and verify the independently published
   manifest digest/signature.
2. Confirm validation job, immutable commit/build, AWS account, Region, rule
   order, capacity, and parser context.
3. Re-run syntax, capacity, duplicate SID, match, and no-match tests.
4. Compare candidate `effective_releases` with the approved reference set and
   priorities.
5. Confirm the LKG ARN is still deployable and not scheduled for removal.

### 2. Establish the observation baseline

1. Bind the candidate observation release in a non-production environment first.
2. Confirm managed groups use only supported managed overrides and customer
   blocking groups select alert-only variants.
3. Observe ALERT, FLOW, and TLS health for the agreed interval.
4. Review would-drop events by SID/group, source/destination, application owner,
   AZ, and expected outcome.
5. Run positive traffic, intentional negative traffic, `HOME_NET` boundary, and
   management-path probes in every AZ.
6. Record error, latency, reset, drop, and cross-AZ baselines.

### 3. Promote selectively

1. Set `enforcement.mode = "selective"` for the candidate release.
2. Move only approved slots whose `enforce_from` threshold permits selective
   enforcement; keep higher-risk slots observable.
3. Save and review the plan; confirm only the intended policy resource/binding
   changes.
4. Apply, then wait for the service to report stable policy and attachment
   status.
5. Repeat all positive, negative, return-path, `HOME_NET`, and management probes.
6. Observe the agreed interval and compare against stop thresholds.

### 4. Promote to enforce

1. Obtain final approval using the selective observation record.
2. Set `enforcement.mode = "enforce"` in a new immutable policy release or the
   approved release configuration, according to your release policy.
3. Confirm the firewall will bind the intended policy ARN and LKG remains.
4. Apply and monitor all AZs continuously through the high-risk interval.
5. Repeat traffic probes and verify expected drops are visible in logs.
6. Record release key, policy ARN, digest, plan, apply result, timestamps, owner,
   approver, and telemetry links.

## Stop or abort conditions

Stop before apply, or roll back immediately after apply, when any of these occur:

- candidate digest/evidence mismatch or untraceable validation context;
- missing or delayed ALERT/FLOW/TLS telemetry;
- any requested AZ is not ready;
- an unexpected Terraform action appears;
- management, DNS, identity, time sync, monitoring, or automation probes fail;
- unexpected cross-AZ or asymmetric traffic appears;
- false-positive/drop/error/latency thresholds are exceeded;
- a customer blocking group lacks a trustworthy observation variant;
- the LKG ARN is absent or rollback authority is unavailable.

## Verification

- Firewall policy ARN equals the approved candidate ARN in every intended stack.
- `effective_releases` shows the approved ARN, mode, reference set, priorities,
  and overrides.
- All endpoint records for requested AZs are healthy or operationally verified.
- Positive and negative probes pass in every AZ in both directions.
- Expected drops appear in ALERT/FLOW data and unexpected drops remain below the
  approved threshold.
- Management-path and `HOME_NET` probes pass.
- LKG policy remains retained and documented.

## Rollback

1. If one group causes harm, set its named `group_overrides` directive to
   `"observe"` with `change_id`, `owner`, and `expires_at`.
2. If impact is broad, set `incident_control.mode = "observe_all_stateful"` with
   the same metadata. Remember that stateless groups remain enforced and customer
   groups require observation variants.
3. If policy structure or references are suspect, rebind the firewall to the
   retained LKG policy ARN.
4. Apply the smallest safe plan, keep logging enabled, and repeat all probes.
5. Open a corrective release; do not treat `expires_at` as an automatic revert.
