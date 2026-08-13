# Upgrade guide: 1.0.2 to 2.0

Version 2 replaces the singleton and positional contracts with caller-keyed maps. Migrate state and behavior separately.

## 1. Capture the baseline

While pinned to v1.0.2, record a clean plan, back up state, and capture:

- `terraform state list` and every resource ID;
- firewall policy ARN, VPC ID, subnet mappings, address family, protection flags, encryption, and tags;
- logging destinations;
- the effective Availability Zone order and every route table/destination represented by each numeric index.

Do not infer the old index-to-zone mapping from reordered source code. Use state and the last clean plan.

## 2. Translate the firewall

Translate values from captured state, not from assumptions about old defaults:

| v1 value | v2 field | Migration rule |
| --- | --- | --- |
| `network_firewall_name` | `firewalls.primary.name` | Preserve exactly; name is physical identity. |
| `network_firewall_policy` | `firewalls.primary.policy_arn` | Preserve the effective ARN. |
| VPC and positional subnet mappings | `placement.vpc.vpc_id` and caller-keyed `endpoint_subnets` | Derive each AZ/subnet pair from state; keep `IPV4` unless the existing mapping proves otherwise. |
| `network_firewall_encryption_key_arn = null` | `encryption = { type = "AWS_OWNED_KMS_KEY" }` or omit | AWS-owned encryption deliberately renders no provider block. |
| `network_firewall_encryption_key_arn = <arn>` | `encryption = { type = "CUSTOMER_KMS", key_arn = <arn> }` | Preserve the exact KMS ARN. |
| v1 description | `description` | Preserve exact text, including null versus non-null. |
| Effective tags produced through `aws-ia/label` | `tags` | Copy the tags observed in state. v2 does not run the label module; compare the full map before moving state. |
| Delete/policy/subnet/AZ protections | `protections` | Reproduce every effective boolean first; safer defaults are a later change. |

The v1 singleton becomes the `primary` key:

```hcl
firewalls = {
  primary = {
    name        = var.network_firewall_name
    description = var.network_firewall_description
    policy_arn  = var.network_firewall_policy
    encryption = {
      type    = "CUSTOMER_KMS"
      key_arn = var.network_firewall_encryption_key_arn
    }
    tags = var.captured_effective_firewall_tags
    placement = {
      vpc = {
        vpc_id = var.vpc_id
        endpoint_subnets = {
          "us-east-1a" = { subnet_id = "subnet-...", ip_address_type = "IPV4" }
        }
      }
    }
    protections = {
      delete                   = false
      policy_change            = false
      subnet_change            = false
      availability_zone_change = false
    }
  }
}
```

The module contains this static move:

```hcl
moved {
  from = aws_networkfirewall_firewall.anfw
  to   = aws_networkfirewall_firewall.this["primary"]
}
```

Reproduce v1 protection flags first. Enable safer defaults in a later change.

## 3. Move logging

Translate every v1 destination before moving state:

| v1 destination value | v2 destination field | Ownership rule |
| --- | --- | --- |
| `logGroupName` | `cloudwatch.log_group_name` | Set `cloudwatch.create = false` for an existing externally owned group. Use `create = true` only when intentionally importing that log group into this module's `aws_cloudwatch_log_group` address. |
| `bucketName` | `s3.bucket_name` | S3 remains inject-only. |
| `logPrefix` | `s3.prefix` | Preserve null/omitted versus an exact prefix. |
| `deliveryStreamName` | `firehose.delivery_stream_name` | Firehose remains inject-only. |
| ALERT/FLOW/TLS type | `logs.<stable-key>.log_type` | One key per distinct type under the firewall's single logging configuration. |

For example, preserving an existing CloudWatch group without adopting it:

```hcl
logging_configurations = {
  primary = {
    firewall_arn = module.nfw.firewall_arns.primary
    logs = {
      alerts = {
        log_type = "ALERT"
        destination = { cloudwatch = {
          create         = false
          log_group_name = "/aws/network-firewall/central-alerts"
        } }
      }
    }
  }
}
```

The unique v2 owner is the public `modules/logging` instance in the caller state. For the conventional caller module name `nfw_logging`, its exact target is `module.nfw_logging.aws_networkfirewall_logging_configuration.this["primary"]`; no root convenience resource competes for ownership. Instantiate the logging submodule with the semantic key `primary`, then add this move in the caller's root configuration, adjusting only the outer module call names when they differ:

```hcl
moved {
  from = module.nfw.module.logging[0].aws_networkfirewall_logging_configuration.anfw_logs
  to   = module.nfw_logging.aws_networkfirewall_logging_configuration.this["primary"]
}
```

The old `count[0]` becomes a caller key. Preserve the same effective log types and destinations during the move.


### Preserve the twelve historical route moves

Upgrades from versions before v1 must retain both six-index historical chains. Never add a competing direct old-to-v2 move. In the caller root, keep old-to-v1 first, then add the caller-specific v1-to-v2 move:

```hcl
moved { from = module.nfw.aws_route.tgw_to_firewall_endpoint[0] to = module.nfw.aws_route.connectivity_to_firewall_endpoint[0] }
moved { from = module.nfw.aws_route.tgw_to_firewall_endpoint[1] to = module.nfw.aws_route.connectivity_to_firewall_endpoint[1] }
moved { from = module.nfw.aws_route.tgw_to_firewall_endpoint[2] to = module.nfw.aws_route.connectivity_to_firewall_endpoint[2] }
moved { from = module.nfw.aws_route.tgw_to_firewall_endpoint[3] to = module.nfw.aws_route.connectivity_to_firewall_endpoint[3] }
moved { from = module.nfw.aws_route.tgw_to_firewall_endpoint[4] to = module.nfw.aws_route.connectivity_to_firewall_endpoint[4] }
moved { from = module.nfw.aws_route.tgw_to_firewall_endpoint[5] to = module.nfw.aws_route.connectivity_to_firewall_endpoint[5] }

moved { from = module.nfw.aws_route.tgw_to_firewall_endpoint_without_egress[0] to = module.nfw.aws_route.connectivity_to_firewall_endpoint_without_egress[0] }
moved { from = module.nfw.aws_route.tgw_to_firewall_endpoint_without_egress[1] to = module.nfw.aws_route.connectivity_to_firewall_endpoint_without_egress[1] }
moved { from = module.nfw.aws_route.tgw_to_firewall_endpoint_without_egress[2] to = module.nfw.aws_route.connectivity_to_firewall_endpoint_without_egress[2] }
moved { from = module.nfw.aws_route.tgw_to_firewall_endpoint_without_egress[3] to = module.nfw.aws_route.connectivity_to_firewall_endpoint_without_egress[3] }
moved { from = module.nfw.aws_route.tgw_to_firewall_endpoint_without_egress[4] to = module.nfw.aws_route.connectivity_to_firewall_endpoint_without_egress[4] }
moved { from = module.nfw.aws_route.tgw_to_firewall_endpoint_without_egress[5] to = module.nfw.aws_route.connectivity_to_firewall_endpoint_without_egress[5] }
```

Each intermediate `connectivity_*[i]` then moves to exactly one semantic `module.nfw_routes.aws_route.this["..."]` address. Consumers with historical indices above 5 require an explicit caller move because v1 never shipped those static historical blocks. The executable `examples/migration_pre_v1_routes/moved.tf` contains both links for all twelve addresses, and the native suite seeds both families at every index while explicitly asserting indices 0 and 5.
## 4. Move routes

There is no safe wildcard move from numeric indices. Create one semantic route key per state address and add explicit caller-root moves. Examples:

```hcl
moved {
  from = module.nfw.aws_route.igw_route_table_to_protected_subnets[0]
  to   = module.nfw_routes.aws_route.this["igw-to-public-a"]
}

moved {
  from = module.nfw.aws_route.protected_route_table_to_internet[0]
  to   = module.nfw_routes.aws_route.this["public-a-default-v4"]
}

moved {
  from = module.nfw.module.intra_vpc_routing[0].aws_route.intra_vpc_route[0]
  to   = module.nfw_routes.aws_route.this["app-a-to-data-a"]
}

moved {
  from = module.nfw.module.central_inspection_with_egress_routing[0].aws_route.route_public_to_firewall_endpoint[0]
  to   = module.nfw_routes.aws_route.this["public-a-to-network-0"]
}
```

Apply the same rule to `connectivity_to_firewall_endpoint[*]` and `connectivity_to_firewall_endpoint_without_egress[*]`: derive the new key from route-table identity, zone, and destination, never from the old index.

If the final owner cannot be addressed by a `moved` block, use a declarative handoff in the old owner and an `import` in the new owner:

```hcl
removed {
  from = module.old_owner.aws_route.example

  lifecycle {
    destroy = false
  }
}
```

Do not manage one route from both modules.

## 5. Complete `centralized_inspection_with_egress` walkthrough

This worked example uses two Availability Zones and two routed spoke CIDRs. Capture this inventory from v1 state before editing configuration:

| Physical object | v1 address | Captured identity |
| --- | --- | --- |
| Firewall | `module.nfw.aws_networkfirewall_firewall.anfw` | firewall ARN/ID |
| Logging | `module.nfw.module.logging[0].aws_networkfirewall_logging_configuration.anfw_logs` | firewall ARN |
| AZ A connectivity | `module.nfw.aws_route.connectivity_to_firewall_endpoint[0]` | `rtb-...001` + `0.0.0.0/0` |
| AZ B connectivity | `module.nfw.aws_route.connectivity_to_firewall_endpoint[1]` | `rtb-...002` + `0.0.0.0/0` |
| AZ A / `10.10.0.0/16` | `module.nfw.module.central_inspection_with_egress_routing[0].aws_route.route_public_to_firewall_endpoint[0]` | `rtb-...011` + CIDR |
| AZ A / `10.20.0.0/16` | `module.nfw.module.central_inspection_with_egress_routing[0].aws_route.route_public_to_firewall_endpoint[1]` | `rtb-...011` + CIDR |
| AZ B / `10.10.0.0/16` | `module.nfw.module.central_inspection_with_egress_routing[1].aws_route.route_public_to_firewall_endpoint[0]` | `rtb-...012` + CIDR |
| AZ B / `10.20.0.0/16` | `module.nfw.module.central_inspection_with_egress_routing[1].aws_route.route_public_to_firewall_endpoint[1]` | `rtb-...012` + CIDR |

The numeric indices above are examples only. Confirm the actual AZ, route table, endpoint, and CIDR at each address with `terraform state show`; never infer them from current list ordering.

The complete v2 configuration is:

```hcl
module "nfw" {
  source  = "aws-ia/networkfirewall/aws"
  version = "~> 2.0"

  firewalls = {
    primary = {
      name        = "central-inspection"
      description = "Preserved v1 description"
      policy_arn  = var.firewall_policy_arn
      placement = { vpc = {
        vpc_id = var.inspection_vpc_id
        endpoint_subnets = {
          "us-east-1a" = { subnet_id = var.firewall_subnet_a_id }
          "us-east-1b" = { subnet_id = var.firewall_subnet_b_id }
        }
      } }
      protections = {
        delete                   = false
        policy_change            = false
        subnet_change            = false
        availability_zone_change = false
      }
      encryption = {
        type    = "CUSTOMER_KMS"
        key_arn = var.network_firewall_encryption_key_arn
      }
      tags = var.captured_effective_firewall_tags
    }
  }
}

module "nfw_logging" {
  source  = "aws-ia/networkfirewall/aws//modules/logging"
  version = "~> 2.0"

  logging_configurations = {
    primary = {
      firewall_arn = module.nfw.firewall_arns.primary
      logs = {
        alerts = {
          log_type = "ALERT"
          destination = { cloudwatch = {
            create         = false
            log_group_name = "/aws/network-firewall/central-alerts"
          } }
        }
      }
    }
  }
}

module "nfw_routes" {
  source  = "aws-ia/networkfirewall/aws//modules/routes"
  version = "~> 2.0"

  vpc_endpoint_ids_by_az = module.nfw.vpc_endpoint_ids_by_firewall_by_az.primary

  routes = {
    tgw-a-default = {
      route_table_id                   = "rtb-00000000000000001"
      availability_zone                = "us-east-1a"
      acknowledge_external_route_table = true
      destination                      = { ipv4_cidr = "0.0.0.0/0" }
    }
    tgw-b-default = {
      route_table_id                   = "rtb-00000000000000002"
      availability_zone                = "us-east-1b"
      acknowledge_external_route_table = true
      destination                      = { ipv4_cidr = "0.0.0.0/0" }
    }
    public-a-spoke-0 = {
      route_table_id                   = "rtb-00000000000000011"
      availability_zone                = "us-east-1a"
      acknowledge_external_route_table = true
      destination                      = { ipv4_cidr = "10.10.0.0/16" }
    }
    public-a-spoke-1 = {
      route_table_id                   = "rtb-00000000000000011"
      availability_zone                = "us-east-1a"
      acknowledge_external_route_table = true
      destination                      = { ipv4_cidr = "10.20.0.0/16" }
    }
    public-b-spoke-0 = {
      route_table_id                   = "rtb-00000000000000012"
      availability_zone                = "us-east-1b"
      acknowledge_external_route_table = true
      destination                      = { ipv4_cidr = "10.10.0.0/16" }
    }
    public-b-spoke-1 = {
      route_table_id                   = "rtb-00000000000000012"
      availability_zone                = "us-east-1b"
      acknowledge_external_route_table = true
      destination                      = { ipv4_cidr = "10.20.0.0/16" }
    }
  }
}
```

Add one move for every physical object whose owner/address changes. The firewall move is distributed inside the root module; keep the caller moves below next to the module calls:

```hcl
# Distributed by the v2 root module:
# module.nfw.aws_networkfirewall_firewall.anfw
#   -> module.nfw.aws_networkfirewall_firewall.this["primary"]

moved {
  from = module.nfw.module.logging[0].aws_networkfirewall_logging_configuration.anfw_logs
  to   = module.nfw_logging.aws_networkfirewall_logging_configuration.this["primary"]
}

moved {
  from = module.nfw.aws_route.connectivity_to_firewall_endpoint[0]
  to   = module.nfw_routes.aws_route.this["tgw-a-default"]
}
moved {
  from = module.nfw.aws_route.connectivity_to_firewall_endpoint[1]
  to   = module.nfw_routes.aws_route.this["tgw-b-default"]
}
moved {
  from = module.nfw.module.central_inspection_with_egress_routing[0].aws_route.route_public_to_firewall_endpoint[0]
  to   = module.nfw_routes.aws_route.this["public-a-spoke-0"]
}
moved {
  from = module.nfw.module.central_inspection_with_egress_routing[0].aws_route.route_public_to_firewall_endpoint[1]
  to   = module.nfw_routes.aws_route.this["public-a-spoke-1"]
}
moved {
  from = module.nfw.module.central_inspection_with_egress_routing[1].aws_route.route_public_to_firewall_endpoint[0]
  to   = module.nfw_routes.aws_route.this["public-b-spoke-0"]
}
moved {
  from = module.nfw.module.central_inspection_with_egress_routing[1].aws_route.route_public_to_firewall_endpoint[1]
  to   = module.nfw_routes.aws_route.this["public-b-spoke-1"]
}
```

Expected before/after addresses:

| v1 family | v2 family | Count |
| --- | --- | ---: |
| `module.nfw.aws_networkfirewall_firewall.anfw` | `module.nfw.aws_networkfirewall_firewall.this["primary"]` | 1 |
| `module.nfw.module.logging[0]...anfw_logs` | `module.nfw_logging...this["primary"]` | 1 |
| `module.nfw.aws_route.connectivity_to_firewall_endpoint[*]` | `module.nfw_routes.aws_route.this["tgw-<az>-default"]` | 2 |
| `module.nfw.module.central_inspection_with_egress_routing[*].aws_route.route_public_to_firewall_endpoint[*]` | `module.nfw_routes.aws_route.this["public-<az>-spoke-<cidr-index>"]` | 4 |

The native fixture executes this exact graph, asserts all eight physical IDs, and also compares description, policy ARN, four protections, customer KMS, effective tags, both subnet mappings, and CloudWatch `create = false` ownership.

## 6. Import identifiers

Use declarative imports in the caller root when no compatible source address exists.

| Resource | `import.id` |
| --- | --- |
| `aws_networkfirewall_firewall` | Firewall ARN |
| `aws_networkfirewall_logging_configuration` | Associated firewall ARN |
| `aws_networkfirewall_firewall_policy` | Policy ARN |
| `aws_networkfirewall_rule_group` | Rule-group ARN |
| `aws_route` | `ROUTE_TABLE_ID_DESTINATION`, for example `rtb-123_0.0.0.0/0`, `rtb-123_::/0`, or `rtb-123_pl-123` |
| `aws_cloudwatch_log_group` | Exact log-group name |

An injected data source cannot move to a managed resource. Remove the data address and import the physical resource at its final managed address. A cross-state handoff always uses a `removed` block with nested `lifecycle { destroy = false }` in the old state plus `import` in the new state. The old-state plan reports this non-destructive handoff as `forget`; approve that exact action and address in the acceptance file.

## 7. Acceptance gate

Rehearse with a state copy. Save the complete normal plan and enforce its JSON actions:

```shell
terraform init
terraform plan -out=v1-to-v2.tfplan

# Resolve the immutable installed source for module "nfw". If your module call
# has another label, replace the exact .Key selector below.
module_dir="$(jq -r '.Modules[] | select(.Key == "nfw") | .Dir' .terraform/modules/modules.json)"
guard="$module_dir/scripts/check-migration-plan.sh"
test -f "$guard"
shasum -a 256 "$guard"
"$guard" v1-to-v2.tfplan
```

For a registry install the usual path is `.terraform/modules/nfw/scripts/check-migration-plan.sh`; resolving `modules.json` avoids guessing. Compare the SHA-256 with the file in the pinned module release before execution.

The first gate always rejects delete/replacement. It also rejects create/update/forget except new `terraform_data` checks. If review explicitly approves a non-destructive action, list the exact action and full address in a separate file:

```text
# approved-actions.txt
update module.nfw_logging.aws_networkfirewall_logging_configuration.this["primary"]
forget module.legacy.terraform_data.handoff["primary"]
```

Then rerun:

```shell
"$guard" v1-to-v2.tfplan approved-actions.txt
```

The script runs `terraform show -json`, rejects every action list containing `delete` (including replacements), and separately rejects every non-allowlisted `create`, `update`, or `forget`. The only automatic create exception is a resource whose structurally parsed type is `terraform_data`; a module label named `terraform_data` does not qualify. A `forget` from `removed { lifecycle { destroy = false } }` is accepted only through an exact action/address approval. Output-ID assertions in native state fixtures are supplementary; they are not the acceptance gate.

Reject the migration plan if it contains any unapproved action beyond state moves and new `terraform_data` checks. In particular, require:

- zero destroy and zero replace of the firewall or endpoints;
- zero delete/create route churn;
- identical firewall ARN/ID, policy ARN, VPC, subnets, address family, protections, encryption, and tags;
- identical logging destinations;
- stable downstream behavior through Tier 1 outputs.

After the migration applies cleanly, change protections, policy, logging, routing, or endpoint address family in separate reviews.
