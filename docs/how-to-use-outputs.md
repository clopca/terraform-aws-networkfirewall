# How to use outputs

Prefer the narrowest stable output that satisfies the composition. The root
module exposes three support tiers; public submodules expose stable composition
outputs plus an unstable `resources` escape hatch.

## Root output tiers

### Tier 1: stable composition contract

Tier 1 outputs are semver-protected for the v2 major line.

| Output | Shape | Primary use |
|---|---|---|
| `firewall_arns` | `map(string)` | Logging and external integrations by firewall key. |
| `firewall_ids` | `map(string)` | Inventory and service API integration. |
| `firewall_names` | `map(string)` | Monitoring dimensions and operator display. |
| `firewall_policy_arns` | `map(string)` | Verify the effective policy binding. |
| `vpc_endpoint_ids_by_firewall_by_az` | `map(map(string))` | Route each AZ to its local Network Firewall endpoint. |
| `vpc_endpoint_records_by_firewall_by_az` | nested object map | Endpoint ID, AZ ID, and readiness semantics. |

Use endpoint IDs directly when readiness is handled by Terraform dependencies
and your deployment procedure. Use endpoint records when automation must expose
whether create-mode health is guaranteed or inject-mode health is unverified.

```hcl
locals {
  primary_endpoint_ids =
    module.network_firewall.vpc_endpoint_ids_by_firewall_by_az.primary

  primary_endpoint_records =
    module.network_firewall.vpc_endpoint_records_by_firewall_by_az.primary
}

output "inspection_endpoint_ids_by_az" {
  value = local.primary_endpoint_ids
}
```

Do not use `values(...)` to discard AZ keys. The AZ name is part of routing
correctness.

### Tier 2: v1 compatibility bridge

`aws_network_firewall` returns the created provider object only when the caller
uses key `primary`; otherwise it is `null`. It is deprecated and removed in v3.
Use it only while moving a v1 consumer to Tier 1 outputs. Do not add new
consumers.

```hcl
# Temporary compatibility only.
output "legacy_firewall_object" {
  value = module.network_firewall.aws_network_firewall
}
```

### Tier 3: unsupported shape escape hatch

`resources` exposes internal provider resource and data-source collections. Its
shape is not semver-protected. It is intended for short-lived diagnostics or a
requirement that has no stable output yet.

```hcl
# Isolate Tier 3 access in one local so it can be removed or adapted explicitly.
locals {
  unsupported_provider_shape = module.network_firewall.resources
}
```

Never pass Tier 3 objects across state, module, or team boundaries. Open a
feature request when a repeatable composition needs a stable field.

## Public submodule outputs

| Module | Stable output | Use |
|---|---|---|
| `modules/logging` | `logging_destination_records` | Effective destination type and handle by configuration/log key. |
| `modules/routes` | `route_ids` | Route identity by caller-controlled route key. |
| `modules/rule-groups` | `rule_group_arns` | Effective created or injected ARN by group key. |
| `modules/rule-groups` | `rule_group_records` | Typed metadata for policy-control composition. |
| `modules/policy-control` | `policy_arns` | Effective policy ARN by immutable release key. |
| `modules/policy-control` | `effective_releases` | Compiled enforcement posture and effective references. |

Each submodule also exposes `resources`; it has the same unsupported Tier 3
status as the root escape hatch.

## Composition recipes

### Firewall to logging

```hcl
module "logging" {
  source = "./modules/logging"

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
}
```

### Rule groups to policy control

Pass records without copying metadata manually. Policy control matches records
by ARN, propagates `requires_home_net`, and rejects incoherent declared kind,
rule order, or capacity.

```hcl
module "policy_control" {
  source = "./modules/policy-control"

  rule_group_records = module.rule_groups.rule_group_records
  policies           = local.policy_releases
}
```

### Policy to firewall

```hcl
module "network_firewall" {
  source  = "aws-ia/networkfirewall/aws"
  version = "~> 2.0"

  firewalls = {
    primary = {
      name       = "inspection"
      policy_arn = module.policy_control.policy_arns[local.active_release]
      placement  = local.firewall_placement
    }
  }
}
```

Keep candidate, active, and last-known-good release keys explicit. Changing the
selected policy ARN is an operational release action; it is not content
discovery.

### Firewall endpoints to native VPC v5 routes

```hcl
routes = {
  application_default = {
    from_group  = "application"
    destination = { type = "ipv4_cidr", value = "0.0.0.0/0" }
    target = {
      type      = "vpc_endpoint"
      ids_by_az = module.network_firewall.vpc_endpoint_ids_by_firewall_by_az.primary
    }
  }
}
```

Native VPC v5 top-level routes accept the late-bound endpoint map and create one
route per module-managed AZ table. An injected shared table cannot select a
zonal target; use one `target.id` or the external route bridge as appropriate.

### Firewall endpoints to external route tables

```hcl
module "routes" {
  source = "./modules/routes"

  vpc_endpoint_ids_by_az =
    module.network_firewall.vpc_endpoint_ids_by_firewall_by_az.primary

  routes = {
    app_a_default = {
      route_table_id                   = var.application_route_table_ids_by_az["us-east-1a"]
      destination                      = { ipv4_cidr = "0.0.0.0/0" }
      availability_zone                = "us-east-1a"
      acknowledge_external_route_table = true
    }
  }
}
```

The acknowledgement is an ownership assertion, not route discovery. Confirm no
other state owns the same route-table/destination pair.

## Cross-state consumption

Publish only Tier 1 or stable submodule values from the producing state. Keep
keys unchanged across `terraform_remote_state`, SSM, or another approved
contract store.

```hcl
locals {
  endpoint_ids_by_az =
    data.terraform_remote_state.firewall.outputs.vpc_endpoint_ids_by_firewall_by_az.primary
}
```

Treat a renamed firewall key or AZ key as a contract migration. Validate that
the full AZ set matches route-table ownership before applying route changes.
