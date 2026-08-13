# ADR 0002: Caller keys are state identity

## Status

Accepted

## Decision

Every public collection is a map keyed by a caller-controlled identifier. Keys use letters, numbers, `.`, `_`, and `-`; `/` is rejected because it is reserved for internal composite identities. List position, map iteration order, discovered Availability Zones, ARN values, and computed IDs never determine resource cardinality.

The v1 singleton firewall moves from `aws_networkfirewall_firewall.anfw` to `aws_networkfirewall_firewall.this["primary"]`. Logging and route migrations depend on the caller's selected semantic keys, so the upgrade guide provides explicit address mappings instead of unsafe wildcard moves.

Endpoint output zone keys always originate in `firewalls[*].placement.vpc.endpoint_subnets`. Inject mode intentionally returns an empty endpoint map because its contract accepts an ARN only and does not invent identity from provider status.
