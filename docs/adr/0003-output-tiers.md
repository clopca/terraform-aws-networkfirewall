# ADR 0003: Output tiers

## Status

Accepted

## Decision

Tier 1 outputs are semver-protected composition handles: firewall ARNs, IDs, names, endpoint IDs by firewall and zone, and endpoint records by firewall and zone. Collection absence is `{}` and optional scalar absence is `null`.

Tier 2 is the v1 migration bridge. `aws_network_firewall` returns the complete created provider object only when the firewall key is `primary`; it is deprecated in v2 and will be removed in v3.

Tier 3 is `resources`, an escape hatch exposing created resources and injected data sources. Its shape follows implementation and provider details and is not semver-protected. Module examples and composition guidance use Tier 1 only.
