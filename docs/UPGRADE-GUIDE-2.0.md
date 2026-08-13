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

The v1 singleton becomes the `primary` key:

```hcl
firewalls = {
  primary = {
    name       = var.network_firewall_name
    policy_arn = var.network_firewall_policy
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

Instantiate the logging submodule with a semantic key such as `primary`. Add this move in the caller's root configuration, adjusting module names to the actual addresses:

```hcl
moved {
  from = module.nfw.module.logging[0].aws_networkfirewall_logging_configuration.anfw_logs
  to   = module.nfw_logging.aws_networkfirewall_logging_configuration.this["primary"]
}
```

The old `count[0]` becomes a caller key. Preserve the same effective log types and destinations during the move.

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

If the final owner cannot be addressed by a `moved` block, use a declarative `removed { destroy = false }` plus `import` in the same reviewed handoff. Do not manage one route from both modules.

## 5. Acceptance gate

Rehearse with a state copy. Reject the migration plan if it contains any unapproved action beyond state moves and new `terraform_data` checks. In particular, require:

- zero destroy and zero replace of the firewall or endpoints;
- zero delete/create route churn;
- identical firewall ARN/ID, policy ARN, VPC, subnets, address family, protections, encryption, and tags;
- identical logging destinations;
- stable downstream behavior through Tier 1 outputs.

After the migration applies cleanly, change protections, policy, logging, routing, or endpoint address family in separate reviews.
