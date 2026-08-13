# ADR 0006: Enforcement rollout distinguishes managed and customer rule groups

## Status

Implemented in 2.0

## Decision

`DROP_TO_ALERT` is not a general observation mechanism. AWS documents `StatefulRuleGroupOverride` as applying only to managed rule groups. A customer rule group, including a custom Suricata ruleset, can continue to drop or reject traffic when a policy is described as observation or selective.

Every stateful rule-group reference declares `kind = "managed" | "customer"`:

- `kind = "managed"` may use `DROP_TO_ALERT` below its configured enforcement level;
- `kind = "customer"` must supply an independently validated alert-only `observation_arn` for non-enforcing modes;
- a customer reference without an observation variant fails plan in `observation` and `selective` rather than presenting false safety;
- terminal `pass` rules and stateless drops remain outside this gate and are documented as always effective.

The implementation enforces the current service limits: no more than 20 stateful and 20 stateless references per policy, priorities from 1 through 65535 with no duplicates, and rule-group capacity from 1 through 30000. Capacity totals are checked only when the required metadata is plan-known; external ARNs remain explicitly unverified.

## Implementation

`modules/policy-control` implements this decision as a pure binding layer. Every stateful slot declares `kind`, STRICT_ORDER compatibility, capacity, enforcement level, and composable behavior `{actions, has_terminal_action, override_coverage}`. A blocking customer slot below its enforcement level must provide an independently validated `observation_arn`; otherwise plan fails with the two safe exits. Only managed slots render `DROP_TO_ALERT`.

`incident_control.group_overrides` takes precedence over `observe_all_stateful`, which takes precedence over `enforce_from`. Temporary posture requires change, owner, and expiry metadata; expiry is deliberately not an automatic Terraform timer. `home_net_cidrs` is the only policy-variable source, engine restart-prone options are explicit, and release keys make TLS presence durable identity.
