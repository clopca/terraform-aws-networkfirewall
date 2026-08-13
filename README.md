# AWS Network Firewall Module

This module creates or references AWS Network Firewall resources with stable caller-defined identity, protected VPC placement, IPv4/IPv6/dual-stack endpoint mappings, typed logging destinations, and an optional route-only bridge.

Firewall policies, VPCs, subnets, route tables, KMS keys, S3 buckets, and Firehose delivery streams remain independently owned and are supplied by ARN or ID.

## Usage

```hcl
module "network_firewall" {
  source  = "aws-ia/networkfirewall/aws"
  version = "~> 2.0"

  firewalls = {
    primary = {
      name       = "inspection"
      policy_arn = aws_networkfirewall_firewall_policy.inspection.arn
      placement = {
        vpc = {
          vpc_id = module.vpc.vpc_id
          endpoint_subnets = {
            for zone, subnet_id in module.vpc.subnet_ids_by_group_by_az.firewall :
            zone => {
              subnet_id       = subnet_id
              ip_address_type = "DUALSTACK"
            }
          }
        }
      }
      tags = { Environment = "production" }
    }
  }
}
```

Create mode is the default and requires `name`, `policy_arn`, and `placement.vpc`. All four firewall protections default to `true`. Inject mode uses `create = false` with `arn` and observes the firewall without taking lifecycle ownership. The normal root call uses one `firewalls.primary` entry; additional keys are for firewalls intentionally sharing the same state, account, Region, owner, and lifecycle.

## Lifecycle impact

| Class | Fields | Effect |
| --- | --- | --- |
| Immutable firewall identity | `name`, `vpc_id`, reserved `transit_gateway_id` | Replaces the Terraform firewall resource. |
| Physical endpoint replacement | endpoint `subnet_id`, `ip_address_type` | Keeps the firewall ARN but replaces the `vpce-*`; update routes only after the replacement endpoint is ready. |
| Mutable | policy ARN, protections, description, analysis types, customer KMS, tags | Updates in place, with service-specific dataplane impact. |

AWS does not support changing a subnet mapping's address family in place. Use a blue/green firewall and cut routes over by AZ; do not treat an IPv4-to-dual-stack change as an ordinary update.

## Logging

Use [`modules/logging`](modules/logging) to configure ALERT, FLOW, and TLS logs. CloudWatch log groups support create or inject; S3 buckets and Firehose delivery streams are injected. `manage = false` deletes the effective Network Firewall logging configuration. Changing `monitoring_dashboard` can create a logging gap because provider 6.60 removes all destinations, changes the setting, and reinstalls them.

```hcl
module "network_firewall_logging" {
  source = "aws-ia/networkfirewall/aws//modules/logging"

  logging_configurations = {
    primary = {
      firewall_arn = module.network_firewall.firewall_arns.primary
      logs = {
        alerts = {
          log_type = "ALERT"
          destination = {
            cloudwatch = { log_group_name = "/aws/network-firewall/alerts" }
          }
        }
      }
    }
  }
}
```

## Routes bridge

[`modules/routes`](modules/routes) creates only caller-keyed `aws_route` resources and preserves endpoint affinity with `availability_zone`. Route tables remain externally owned. IPv4 and IPv6 CIDR destinations are supported; AWS provider 6.59 rejects managed prefix-list destinations combined with Network Firewall endpoint targets, so the bridge fails closed and asks callers to expand those entries to CIDR routes.

## Outputs

Stable outputs are `firewall_arns`, `firewall_ids`, `firewall_names`, `firewall_policy_arns`, `vpc_endpoint_ids_by_firewall_by_az`, and `vpc_endpoint_records_by_firewall_by_az`. Endpoint records include AZ name, optional AZ ID, address family, and `readiness_guarantee`; they do not invent a provider resource status. The deprecated `aws_network_firewall` output is a v1 bridge for a created firewall under key `primary`. `resources` is an implementation escape hatch without a stable shape guarantee.

## Examples

- [`basic`](examples/basic): a dual-stack firewall in caller-owned subnets.
- [`complete_logging`](examples/complete_logging): ALERT, FLOW, and TLS with CloudWatch, S3, and Firehose destinations.

## Upgrade

Follow the [2.0 upgrade guide](docs/UPGRADE-GUIDE-2.0.md) and require a complete plan with zero firewall, endpoint, logging, or route destruction before applying.
