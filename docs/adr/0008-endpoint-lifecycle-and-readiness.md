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

Terraform variable preconditions cannot compare a proposed family with its prior state value. The public contract therefore fails closed for every non-IPv4 mapping when `address_family_migration_ack` is known and not `true`. Callers should supply a literal `true` to acknowledge a new mapping or reviewed blue/green cutover; it is not evidence that an in-place family mutation is safe. Terraform defers a precondition whose boolean is unknown during plan, so a computed acknowledgement may not be checked until apply and this module cannot promise plan-known enforcement. Native tests apply IPV4, prove that DUALSTACK on the same firewall/AZ key fails without acknowledgement, passes with literal `true`, and document that an unknown acknowledgement defers the gate.

Known `availability_zone_id` values must be unique across endpoint mappings. Subnet IDs or AZ metadata that remain unknown during planning cannot be looked up reliably without changing the module's ownership and credential boundary, so AWS validates their actual VPC/AZ at apply. The contract documents that deferred limit instead of claiming map keys prove physical subnet placement.

## Readiness

Provider 6.60 waits for global firewall `READY` during managed create and update, so dependants in the same graph need no additional barrier. The resource flattens only AZ, endpoint ID, and subnet ID; records therefore do not invent a `status` field.

Each endpoint record instead declares `readiness_guarantee`:

- `provider_waited` for a managed firewall;
- `observed_ready` for an injected firewall only when global status is `READY`, configuration sync is `IN_SYNC`, and every requested AZ/subnet attachment is `READY` at refresh;
- `unverified` when any global, sync, or requested attachment condition is not ready.

Injected placement is optional observation metadata. When supplied, its AZ/subnet pairs are checked against the data source and provide plan-known output keys; when omitted, endpoint maps are empty.
