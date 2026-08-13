# ADR 0008: Firewall identity, endpoint replacement, and readiness

## Status

Accepted

## Lifecycle impact

| Class | Fields | Effect |
| --- | --- | --- |
| Immutable resource identity | `name`, `placement.vpc.vpc_id`, reserved `transit_gateway_id` | Replaces the `aws_networkfirewall_firewall` resource. |
| Physical endpoint replacement | `endpoint_subnets[*].subnet_id`, `endpoint_subnets[*].ip_address_type` | The firewall ARN remains, but AWS removes and creates an endpoint; the `vpce-*` ID changes and routes must be cut over. |
| Mutable | policy ARN, protections, description, analysis types, customer KMS setting, tags | Updates the firewall resource; dataplane impact still requires review. |

AWS declares a subnet mapping's address family immutable, while provider 6.60 models a family diff as associate/disassociate rather than Terraform resource replacement. A family change is therefore not an ordinary update. The supported path is a blue/green firewall: create the new family under a new firewall key, wait for `READY`, cut routes by AZ, verify traffic, and retire the old firewall. AWS offers no flow-drain or continuity guarantee.

Terraform variable preconditions can validate a proposed family but cannot compare it with a prior state value. The module does not claim that a syntactic precondition can detect history. `subnet_change_protection = true` remains the default AWS guard, the upgrade gate rejects mapping diffs, and an acceptance/state test must detect endpoint-ID change. A future provider plan modifier or stateful contract primitive is required for a true historical plan-time rejection.

## Readiness

Provider 6.60 waits for global firewall `READY` during managed create and update, so dependants in the same graph need no additional barrier. The resource flattens only AZ, endpoint ID, and subnet ID; records therefore do not invent a `status` field.

Each endpoint record instead declares `readiness_guarantee`:

- `provider_waited` for a managed firewall;
- `observed_ready` for an injected firewall whose data-source attachment was `READY` at refresh;
- `unverified` when injected readiness was not observed.

Injected placement is optional observation metadata. When supplied, its AZ/subnet pairs are checked against the data source and provide plan-known output keys; when omitted, endpoint maps are empty.
