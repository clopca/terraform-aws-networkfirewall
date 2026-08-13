# Output contracts

The module groups root outputs into three tiers so consumers can choose between
stable composition handles, temporary v1 compatibility, and an unstable escape
hatch. Public submodules follow the same rule: named composition outputs are the
contract, while `resources` is not. New integrations should start with Tier 1.

## Choose the lowest tier that solves the integration

| Tier | Intended use | Compatibility |
| --- | --- | --- |
| Tier 1 — stable handles | Normal composition through firewall IDs/ARNs/names, effective policy ARNs, and endpoint maps keyed by firewall and AZ | Names, value types, and existing collection keys are semver-protected for v2. Minor releases may add outputs or record attributes. |
| Tier 2 — deprecated v1 bridge | Keeping a v1 consumer operational while it moves to Tier 1 | Preserved for v2 and removed in v3. Available only for a created firewall keyed `primary`. |
| Tier 3 — `resources` | Accessing an internal provider attribute that Tier 1 does not expose | No shape guarantee; collection structure or provider attributes may change in any release. |

If an integration can use a Tier 1 scalar or map instead of a provider object,
use the Tier 1 value. This keeps downstream plans independent of provider schema
changes and root implementation details.

## Tier 1: stable root composition

### Select firewall identity by caller key

The `firewalls` map key is preserved across all identity outputs:

```hcl
locals {
  firewall_key = "primary"

  firewall_arn  = module.network_firewall.firewall_arns[local.firewall_key]
  firewall_id   = module.network_firewall.firewall_ids[local.firewall_key]
  firewall_name = module.network_firewall.firewall_names[local.firewall_key]
  policy_arn    = module.network_firewall.firewall_policy_arns[local.firewall_key]
}
```

The values are effective for both lifecycle modes. Create mode reads the managed
resource; inject mode reads the observed firewall data source. Consumers do not
need to branch on ownership.

Optional collections return `{}` rather than disappearing. Preserve firewall
keys in remote-state or SSM contracts because a rename changes the public map key
and the producer's Terraform resource address.

### Route with endpoint IDs by AZ

`vpc_endpoint_ids_by_firewall_by_az` is the normal route target:

```hcl
module "routes" {
  source = "./modules/routes"

  vpc_endpoint_ids_by_az =
    module.network_firewall.vpc_endpoint_ids_by_firewall_by_az.primary

  routes = {
    workload_a_default = {
      route_table_id                   = var.route_table_ids_by_az["us-east-1a"]
      destination                      = { ipv4_cidr = "0.0.0.0/0" }
      availability_zone                = "us-east-1a"
      acknowledge_external_route_table = true
    }
  }
}
```

Do not call `values(...)` and select by position. The AZ key is part of routing
correctness: every route table must target the endpoint in its own AZ.

VPC v5 can consume the same map through late-bound top-level routes:

```hcl
routes = {
  inspected_default = {
    from_group  = "application"
    destination = { type = "ipv4_cidr", value = "0.0.0.0/0" }
    target = {
      type      = "vpc_endpoint"
      ids_by_az = module.network_firewall.vpc_endpoint_ids_by_firewall_by_az.primary
    }
  }
}
```

Use VPC v5 native routes when that state owns the route tables. Use
`modules/routes` only for route tables whose lifecycle remains elsewhere.

### Endpoint records and readiness

`vpc_endpoint_records_by_firewall_by_az` adds placement and readiness metadata to
the endpoint ID:

```hcl
locals {
  primary_records =
    module.network_firewall.vpc_endpoint_records_by_firewall_by_az.primary

  endpoint_a          = local.primary_records["us-east-1a"].vpc_endpoint_id
  endpoint_a_subnet   = local.primary_records["us-east-1a"].subnet_id
  endpoint_a_az_id    = local.primary_records["us-east-1a"].availability_zone_id
  endpoint_a_family   = local.primary_records["us-east-1a"].ip_address_type
  endpoint_a_readiness = local.primary_records["us-east-1a"].readiness_guarantee
}
```

Each record contains:

| Attribute | Meaning |
| --- | --- |
| `vpc_endpoint_id` | Effective `vpce-*` ID, or `null` if an injected lookup cannot match the requested mapping. |
| `subnet_id` | Input subnet identity for this endpoint mapping. |
| `availability_zone` | Caller-supplied real AZ name and map key. |
| `availability_zone_id` | Optional physical AZ ID declared by the caller. |
| `ip_address_type` | Requested endpoint family (`IPV4`, `IPV6`, or `DUALSTACK`). |
| `readiness_guarantee` | `provider_waited` for managed create-mode attachments, `observed_ready` for a fully matched injected firewall, or `unverified`. |

`provider_waited` means the provider completed its managed firewall operation; it
does not prove route symmetry or application traffic. `observed_ready` is a
point-in-time data-source observation. Treat `unverified` as a stop condition for
route cutover until AWS attachment state is checked directly.

### Compose logging

The root firewall ARN is the stable input to the logging submodule:

```hcl
logging_configurations = {
  primary = {
    firewall_arn = module.network_firewall.firewall_arns.primary
    logs = {
      alert = {
        log_type = "ALERT"
        destination = {
          cloudwatch = { log_group_name = "/aws/network-firewall/alert" }
        }
      }
    }
  }
}
```

`logging_destination_records` returns the effective destination type and handle
by configuration key and log key. It is the stable output for monitoring and
inventory. `resources.cloudwatch_log_groups` and the provider logging object are
Tier 3.

### Compose rule groups and policy control

Pass the record map directly rather than copying metadata:

```hcl
module "policy_control" {
  source = "./modules/policy-control"

  rule_group_records = module.rule_groups.rule_group_records
  policies           = local.policy_releases
}
```

`rule_group_arns` is the scalar ARN map. `rule_group_records` adds type, rule
order, declared capacity, kind, content ownership, HOME_NET requirement, and
validation mode. Policy control matches records by ARN and rejects incoherent
metadata copied into a policy slot.

Policy-control outputs serve different consumers:

- `policy_arns` binds a firewall to an immutable release key;
- `effective_releases` exposes compiled stateful reference ARNs, managed-only
  overrides, enforcement posture, and incident-control results without rule
  content.

```hcl
locals {
  active_policy_arn =
    module.policy_control.policy_arns[local.active_release]
  active_posture =
    module.policy_control.effective_releases[local.active_release]
}
```

Keep candidate, active, and last-known-good keys explicit. Changing the selected
ARN is an operational release action, not content discovery.

### Stable public submodule outputs

| Module | Output | Contract |
| --- | --- | --- |
| Logging | `logging_destination_records` | Effective destinations by configuration and log key. |
| Routes | `route_ids` | Managed route IDs by caller route key. |
| Rule groups | `rule_group_arns` | Effective created or injected ARN by group key. |
| Rule groups | `rule_group_records` | Typed identity, ownership, and policy-composition metadata. |
| Policy control | `policy_arns` | Effective policy ARN by immutable release key. |
| Policy control | `effective_releases` | Compiled binding and enforcement posture. |

## Tier 2: migrate v1 consumers, then remove the bridge

`aws_network_firewall` exposes the created provider object only when the caller
uses key `primary`; otherwise it returns `null`:

```text
# Temporary v1-compatible dependency.
firewall_arn = module.network_firewall.aws_network_firewall.arn

# Final Tier 1 dependency.
firewall_arn = module.network_firewall.firewall_arns.primary
```

Do not add new consumers. Track bridge removal before upgrading to v3, and use
the [2.0 upgrade guide](UPGRADE-GUIDE-2.0.md) to separate state migration from
downstream output refactoring.

## Tier 3: use the escape hatch deliberately

Every public module exposes `resources` for advanced access to internal provider
objects. Isolate the dependency in one local and record why Tier 1 is
insufficient:

```hcl
locals {
  unsupported_firewall_provider_shape =
    module.network_firewall.resources.firewalls["primary"]
}
```

Do not pass Tier 3 objects through remote state, SSM, wrapper-module outputs, or
team boundaries. If the same provider field is needed repeatedly, request a
narrow stable output instead.

## Explore outputs safely

After plan or apply, inspect values without republishing provider objects:

```shell
terraform output
terraform output -json vpc_endpoint_ids_by_az
terraform console
```

Useful console expressions are:

```console
module.network_firewall.firewall_arns
module.network_firewall.vpc_endpoint_ids_by_firewall_by_az.primary
module.network_firewall.vpc_endpoint_records_by_firewall_by_az.primary
module.rule_groups.rule_group_records
module.policy_control.effective_releases
```

## Consumer checklist

- Prefer Tier 1 IDs, ARNs, and typed records over provider objects.
- Preserve firewall, rule-group, policy-release, route, and AZ map keys.
- Keep AZ names attached to endpoint IDs through route creation.
- Treat `unverified` readiness as an operational stop condition.
- Pass `rule_group_records` directly to policy control.
- Use Tier 2 only during v1 migration and remove it before v3.
- Isolate Tier 3 references and expect their shape to change.
