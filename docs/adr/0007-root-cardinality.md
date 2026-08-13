# ADR 0007: Root cardinality remains caller-keyed

## Status

Accepted

## Decision

The root keeps `firewalls = map(object(...))`, despite one firewall being the common case. AWS permits multiple independent firewalls in the same account and Region, and a fabric stack can legitimately own inspection firewalls for multiple VPCs under one provider and release boundary. Keeping one map also preserves the v1 singleton migration at `this["primary"]` and the approved plural inventory outputs without a second wrapper contract.

The convention is strict:

- a normal module call contains exactly one entry named `primary`;
- additional keys are used only when the same team, state, account, Region, and lifecycle boundary intentionally own multiple firewalls;
- different accounts or Regions use separate module calls with provider aliases;
- a key is state identity, not a display name; renaming it requires an explicit `moved` block.

This choice is not based on an AWS need for a multi-firewall resource. It is an ownership convenience for the minority multi-VPC fabric case, while `primary` keeps the 99-percent path and v1 bridge predictable.
