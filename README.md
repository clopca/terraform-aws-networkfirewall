# AWS Network Firewall Module

This module creates or references AWS Network Firewall resources with stable caller-defined identity, protected VPC placement, IPv4/IPv6/dual-stack endpoint mappings, typed logging destinations, and an optional route-only bridge.

Firewall policies, VPCs, subnets, route tables, KMS keys, S3 buckets, and Firehose delivery streams remain independently owned and are supplied by ARN or ID.

## Quick start

The minimal path accepts existing VPC, subnet, and policy handles without depending on another module's output shape:

```hcl
terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.59, < 7.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "vpc_id" {
  type = string
}

variable "firewall_policy_arn" {
  type = string
}

variable "endpoint_subnet_ids_by_az" {
  type = map(string)
}

module "network_firewall" {
  source  = "aws-ia/networkfirewall/aws"
  version = "~> 2.0"

  firewalls = {
    primary = {
      name       = "inspection"
      policy_arn = var.firewall_policy_arn
      placement = {
        vpc = {
          vpc_id = var.vpc_id
          endpoint_subnets = {
            for availability_zone, subnet_id in var.endpoint_subnet_ids_by_az :
            availability_zone => {
              subnet_id       = subnet_id
              ip_address_type = "IPV4"
            }
          }
        }
      }
      tags = { Environment = "production" }
    }
  }
}
```

```shell
terraform init
terraform validate
terraform plan
```

Create mode is the default and requires `name`, `policy_arn`, and `placement.vpc`. All four firewall protections default to `true`. Inject mode uses `create = false` with `arn` and observes the firewall without taking lifecycle ownership. The normal root call uses one `firewalls.primary` entry; additional keys are for firewalls intentionally sharing the same state, account, Region, owner, and lifecycle. VPC module v5 composition is documented separately and requires that output contract to be available.

## Lifecycle impact

| Class | Fields | Effect |
| --- | --- | --- |
| Immutable firewall identity | `name`, `vpc_id`, reserved `transit_gateway_id` | Replaces the Terraform firewall resource. |
| Physical endpoint replacement | endpoint `subnet_id`, `ip_address_type` | Keeps the firewall ARN but replaces the `vpce-*`; update routes only after the replacement endpoint is ready. |
| Mutable | policy ARN, protections, description, analysis types, customer KMS, tags | Updates in place, with service-specific dataplane impact. |

AWS does not support changing a subnet mapping's address family in place. Every new `IPV6` or `DUALSTACK` mapping therefore requires `address_family_migration_ack = true`; supply a literal `true` to acknowledge that the mapping is new or part of a reviewed blue/green cutover, not to authorize a casual in-place mutation. If the boolean is computed and unknown during plan, Terraform defers this precondition until apply; the module cannot force an unknown value to fail at plan time. Use a new firewall key, wait for readiness, cut routes over by AZ, and retire the old firewall.

Known `availability_zone_id` values must be unique across `endpoint_subnets`. Terraform cannot prove a subnet's real VPC/AZ when those handles are unknown at plan time, so AWS remains the authority for unresolved subnet metadata.

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

## Rule groups and policy control

[`modules/rule-groups`](modules/rule-groups) is Suricata-first and also supports closed domain-list, native stateful, and stateless lanes. It validates required IP/port bindings, Suricata SID uniqueness/ranges, capacity, source XOR, and attestation shape before AWS apply; manifest independence must be enforced by CI.

AWS supports three operational ownership models, all first-class here:

| Model | Use when | Content owner |
| --- | --- | --- |
| IaC pure | Rules move through reviewed Terraform releases. | `content_management = "terraform"`; Terraform detects content drift. |
| AWS managed | AWS-maintained StrictOrder threat intelligence is appropriate. | AWS updates content; Terraform binds the managed ARN. |
| Dynamic SecOps | SOC/SOAR must update IOCs or signatures in seconds to minutes. | `content_management = "external"`; Terraform owns group structure and ignores post-bootstrap content. |

[`modules/policy-control`](modules/policy-control) is a pure policy-release and ARN-binding layer. Its slots accept AWS managed ARNs, outputs from `modules/rule-groups`, or external SOC/pipeline ARNs. Rule content never enters the contract, so a referenced content update does not appear in its plan; an apply changes only structure. The provider exposes no rule-group data source, so ARN existence and metadata such as kind/capacity are caller attestations checked for internal consistency but not remotely discovered.

Policy control supports only `STRICT_ORDER`, emits `DROP_TO_ALERT` only for managed groups, requires customer alert-only variants when a blocking group is observed, models composable behavior/override coverage, and provides incident-wide plus per-group overrides. Policy keys are immutable release identities ending `-plain` or `-tls`; use simultaneous candidate, active, and last-known-good releases rather than toggling TLS or overwriting rollback policy.

## Routes bridge

[`modules/routes`](modules/routes) creates only caller-keyed `aws_route` resources and preserves endpoint affinity with `availability_zone`. Route tables remain externally owned. IPv4 and IPv6 CIDR destinations are supported; AWS provider 6.59 rejects managed prefix-list destinations combined with Network Firewall endpoint targets, so the bridge fails closed and asks callers to expand those entries to CIDR routes.

## Outputs

Stable outputs are `firewall_arns`, `firewall_ids`, `firewall_names`, `firewall_policy_arns`, `vpc_endpoint_ids_by_firewall_by_az`, and `vpc_endpoint_records_by_firewall_by_az`. Endpoint records include AZ name, optional AZ ID, address family, and `readiness_guarantee`; they do not invent a provider resource status. The deprecated `aws_network_firewall` output is a v1 bridge for a created firewall under key `primary`. `resources` is an implementation escape hatch without a stable shape guarantee.

## Examples

- [`basic`](examples/basic): a dual-stack firewall in caller-owned subnets.
- [`complete_logging`](examples/complete_logging): ALERT, FLOW, and TLS with CloudWatch, S3, and Firehose destinations.
- [`complete_routes`](examples/complete_routes): two-AZ firewall composition with caller-owned route tables and explicit route ownership acknowledgement.
- [`migration_pre_v1_routes`](examples/migration_pre_v1_routes): executable twelve-route old→v1→semantic-key migration chain.
- [`rule_groups_suricata`](examples/rule_groups_suricata): an attested Suricata bundle with typed IP/port bindings and SID range.
- [`policy_control_gate`](examples/policy_control_gate): observation/selective/enforce, incident overrides, and candidate/active/LKG releases.

## Upgrade

Follow the [2.0 upgrade guide](docs/UPGRADE-GUIDE-2.0.md) and require a complete plan with zero firewall, endpoint, logging, or route destruction before applying.
