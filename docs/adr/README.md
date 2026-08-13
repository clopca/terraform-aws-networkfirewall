# Architecture decision records

This index separates decision status from delivery status. Existing ADR bodies
retain their historical status wording.

| ADR | Decision status | Delivery | Summary |
|---|---|---|---|
| [0001](0001-module-boundaries.md) | Accepted | Implemented in 2.0 | Separate firewall, logging, route, rule-content, and policy ownership. |
| [0002](0002-key-and-state-identity.md) | Accepted | Implemented in 2.0 | Caller-controlled map keys are durable state identity. |
| [0003](0003-output-tiers.md) | Accepted | Implemented in 2.0 | Stable Tier 1 composition, deprecated Tier 2 bridge, unstable Tier 3 escape hatch. |
| [0004](0004-safe-defaults.md) | Accepted | Implemented in 2.0 | Create-mode protections and AWS-owned encryption default on. |
| [0005](0005-provider-baseline.md) | Accepted | Implemented in 2.0 | Terraform 1.7+ and AWS provider 6.59–6.x baseline. |
| [0006](0006-enforcement-rollout.md) | Accepted | Implemented in 2.0 | Managed and customer groups need distinct observation mechanisms. |
| [0007](0007-root-cardinality.md) | Accepted | Implemented in 2.0 | Root remains a caller-keyed firewall map. |
| [0008](0008-endpoint-lifecycle-and-readiness.md) | Accepted | Implemented in 2.0 | Endpoint replacement and readiness are explicit lifecycle contracts. |
| [0009](0009-endpoint-association-reservation.md) | Proposed | Not implemented | Reserve a future one-subnet-per-association shape. |
| [0010](0010-rule-group-ownership-boundary.md) | Accepted | Implemented in 2.0 | Policy control binds typed ARNs and never owns rule content. |

## Status meanings

- **Proposed:** under consideration and not part of the current public contract.
- **Accepted:** the decision governs the current design.
- **Superseded:** replaced by a later ADR; the later record should be linked.
- **Delivery:** states whether the accepted/proposed decision is implemented in a
  released major-line contract.

New ADRs should include context, decision, alternatives, consequences, migration
or lifecycle impact, and explicit status. Do not rewrite historical reasoning to
match a later implementation; add a superseding ADR instead.
