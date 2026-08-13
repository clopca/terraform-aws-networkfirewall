# ADR 0006: Enforcement rollout distinguishes managed and customer rule groups

## Status

Accepted for the phase-2 contract

## Decision

`DROP_TO_ALERT` is not a general observation mechanism. AWS documents `StatefulRuleGroupOverride` as applying only to managed rule groups. A customer rule group, including a custom Suricata ruleset, can continue to drop or reject traffic when a policy is described as observation or selective.

Every future stateful rule-group reference will declare `kind = "managed" | "customer"`:

- `kind = "managed"` may use `DROP_TO_ALERT` below its configured enforcement level;
- `kind = "customer"` must supply an independently validated alert-only `observation_arn` for non-enforcing modes;
- a customer reference without an observation variant fails plan in `observation` and `selective` rather than presenting false safety;
- terminal `pass` rules and stateless drops remain outside this gate and are documented as always effective.

Phase 2 will also enforce the current service limits: no more than 20 stateful and 20 stateless references per policy, priorities from 1 through 65535 with no duplicates, and rule-group capacity from 1 through 30000. Capacity totals are checked only when the required metadata is plan-known; external ARNs remain explicitly unverified.
