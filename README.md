<!-- BEGIN_TF_DOCS -->
# AWS Network Firewall Terraform module

[![Terraform Registry](https://img.shields.io/badge/Terraform%20Registry-aws--ia%2Fnetworkfirewall-844FBA?logo=terraform)](https://registry.terraform.io/modules/aws-ia/networkfirewall/aws/latest)
[![CI](https://github.com/aws-ia/terraform-aws-networkfirewall/actions/workflows/ci.yml/badge.svg)](https://github.com/aws-ia/terraform-aws-networkfirewall/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/aws-ia/terraform-aws-networkfirewall)](LICENSE)

This module creates or observes AWS Network Firewall firewalls and publishes
Availability-Zone-keyed endpoint maps for zonal routing. It composes with the
`aws-ia/vpc/aws` v5 output contract and keeps firewall, route, logging,
rule-content, and policy-release ownership explicit.

The root module owns firewall placement and lifecycle only. Public submodules
optionally own logging associations, rule groups, policy releases, or routes in
externally owned route tables. VPCs, route tables, KMS keys, S3 buckets,
Firehose delivery streams, and any resource not selected explicitly remain
external.

> [!IMPORTANT]
> Upgrading from v1? Follow the [2.0 upgrade guide](docs/UPGRADE-GUIDE-2.0.md)
> before changing configuration or state. Continue only when the migration plan
> has no delete or replace actions and every create, update, or forget action is
> expected and explicitly approved.

## Navigation

- [Key capabilities](#key-capabilities)
- [Cost warning](#cost-warning)
- [Quick start](#quick-start)
- [Compose with AWS IA VPC v5](#compose-with-aws-ia-vpc-v5)
- [Choose a path](#choose-a-path)
- [Module map](#module-map)
- [Rule-content ownership](#rule-content-ownership)
- [Operational policy gate](#operational-policy-gate)
- [Lifecycle and migration](#lifecycle-and-migration)
- [Documentation](#documentation)
- [Examples](#examples)
- [Testing](#testing)
- [Inputs](#inputs)
- [Outputs](#outputs)

## Key capabilities

- **Zonal endpoint identity:** subnet mappings and endpoint outputs use
  caller-supplied Availability Zone names; routes select the endpoint in the
  route table's own AZ.
- **VPC v5 composition:** `subnet_ids_by_group_by_az` feeds firewall placement,
  and zonal endpoint IDs feed native VPC routes or the external-table route bridge.
- **Explicit ownership:** create or observe firewalls at the root; add logging,
  rule groups, policy releases, and routes only through their public submodules.
- **Protected defaults:** delete, policy-change, subnet-change, and
  Availability-Zone-change protections default to `true`.
- **IPv4, IPv6, and dual stack:** each endpoint declares its address family;
  non-IPv4 mappings require an explicit reviewed acknowledgement.
- **Guarded security releases:** policy control models immutable candidate,
  active, and last-known-good releases plus incident-wide and per-group overrides.
- **Non-destructive migration tooling:** tested state moves and the plan guard
  reject destructive or unapproved migration actions.

## Cost warning

> [!WARNING]
> `terraform apply` creates one billable AWS Network Firewall endpoint for each
> configured subnet mapping and incurs traffic-processing charges. CloudWatch
> Logs, S3, Firehose, NAT Gateway, KMS, and cross-AZ data transfer can add
> separate charges. Review [AWS Network Firewall pricing](https://aws.amazon.com/network-firewall/pricing/)
> and each example's prerequisites before applying. `terraform init` and
> `terraform validate` create no AWS resources.

## Quick start

### Prerequisites

- Terraform `>= 1.7` and AWS Provider `>= 6.59, < 7.0`.
- One existing VPC and one dedicated firewall subnet in every selected AZ.
- An existing AWS Network Firewall policy ARN in the same account and Region.
- AWS credentials only for `plan` or `apply`; documentation smoke tests require none.

The Registry source below is the canonical v2 usage. Repository tests extract
this block and replace only the module source with the local checkout so the
contract remains testable before and after publication.

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
  region = var.aws_region
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_id" {
  type = string
}

variable "firewall_policy_arn" {
  type = string
}

variable "firewall_subnet_ids_by_az" {
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
            for az, subnet_id in var.firewall_subnet_ids_by_az :
            az => {
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

output "firewall_arn" {
  value = module.network_firewall.firewall_arns.primary
}

output "vpc_endpoint_ids_by_az" {
  value = module.network_firewall.vpc_endpoint_ids_by_firewall_by_az.primary
}
```

Example `terraform.tfvars`:

```hcl
aws_region          = "us-east-1"
vpc_id              = "vpc-0123456789abcdef0"
firewall_policy_arn = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/inspection"
firewall_subnet_ids_by_az = {
  us-east-1a = "subnet-01111111111111111"
  us-east-1b = "subnet-02222222222222222"
}
```

```shell
terraform init
terraform validate
terraform plan -out=tfplan
```

The values above are placeholders. Replace all IDs and ARNs before planning.
Creating endpoints does not route traffic; compose native VPC v5 routes or
[`modules/routes`](modules/routes) and model both directions explicitly.

Create mode is the default. Set `create = false` with an ARN to observe an
existing firewall without adopting lifecycle ownership. Keep firewalls in
separate states unless they deliberately share account, Region, owner, release
cadence, and failure domain.

## Compose with AWS IA VPC v5

VPC v5 can create the VPC, dedicated firewall subnets, route tables, and zonal
NAT resources. Its stable subnet map feeds the firewall, and the firewall's
stable endpoint map feeds routes without flattening AZ identity:

```hcl
module "vpc" {
  source  = "aws-ia/vpc/aws"
  version = "~> 5.0"

  vpc = { name = "inspected-application" }
  addressing = {
    primary = { cidr_block = "10.20.0.0/16" }
  }
  availability_zones = {
    names = ["us-east-1a", "us-east-1b"]
  }
  subnets = {
    firewall = {
      role = "private"
      ipv4 = { cidrs_by_az = {
        us-east-1a = "10.20.1.0/28"
        us-east-1b = "10.20.1.16/28"
      } }
    }
  }
}

module "network_firewall" {
  source  = "aws-ia/networkfirewall/aws"
  version = "~> 2.0"

  firewalls = {
    primary = {
      name       = "inspected-application"
      policy_arn = var.firewall_policy_arn
      placement = { vpc = {
        vpc_id = module.vpc.vpc_id
        endpoint_subnets = {
          for az, subnet_id in module.vpc.subnet_ids_by_group_by_az.firewall :
          az => { subnet_id = subnet_id }
        }
      } }
    }
  }
}
```

```mermaid
flowchart LR
  VPC[VPC v5 subnet map by AZ] --> FW[Root firewall and endpoints]
  RG[Rule groups] --> PC[Policy releases]
  PC --> FW
  FW --> EP[Endpoint IDs by AZ]
  EP --> VR[VPC v5 native routes]
  EP --> RB[External route-table bridge]
  FW --> LOG[Logging association]
```

VPC v5 owns its VPC, subnets, route tables, and native routes. This module owns
firewall endpoint mappings. Use [`modules/routes`](modules/routes) only for
route tables owned outside VPC v5 or integrations that cannot use its native
late-bound route target. See [VPC v5 composition](docs/VPC-V5-COMPOSITION.md)
and [`end_to_end_vpc_v5`](examples/end\_to\_end\_vpc\_v5).

## Choose a path

| Need | Start with | Add | Main prerequisite or cost |
|---|---|---|---|
| Existing VPC and policy | [`basic`](examples/basic) | Root only | Dedicated subnets; endpoints do not route traffic by themselves. |
| Complete two-AZ inspected VPC | [`end_to_end_vpc_v5`](examples/end\_to\_end\_vpc\_v5) | VPC v5, rules, policy, routes, logging | Two NFW endpoints and two NAT Gateways if applied. |
| Central inspection without Internet egress | [`centralized_without_egress_routes`](examples/centralized\_without\_egress\_routes) | Root and route bridge | Existing TGW, appliance mode, route tables, and complete spoke CIDR inventory. |
| Central inspection with egress | [`centralized_with_egress_routes`](examples/centralized\_with\_egress\_routes) | Root and route bridge | Existing TGW/NAT/IGW fabric; SNAT occurs after inspection. |
| Observe an externally managed firewall | [`inject_existing_firewall`](examples/inject\_existing\_firewall) | Root inject mode | Existing ARN plus observed placement metadata; no lifecycle adoption. |
| Add ALERT, FLOW, or TLS logs | [`complete_logging`](examples/complete\_logging) | `modules/logging` | CloudWatch can be created; S3 and Firehose remain external. |
| Publish Suricata content | [`rule_groups_suricata`](examples/rule\_groups\_suricata) | `modules/rule-groups` | Independent evidence or explicit AWS-first validation. |
| Promote policy releases | [`policy_control_gate`](examples/policy\_control\_gate) | `modules/policy-control` | STRICT\_ORDER groups and customer observation variants. |
| Migrate v1/pre-v1 state | [`migration_pre_v1_routes`](examples/migration\_pre\_v1\_routes) | Upgrade guide and plan guard | Rehearsed copied state and zero destructive actions. |

## Module map

| Module | Use it when | Owns | Deliberately does not own |
|---|---|---|---|
| [`modules/logging`](modules/logging) | A firewall needs ALERT, FLOW, or TLS destinations. | One logging configuration per firewall; optional CloudWatch log groups. | S3 buckets, Firehose streams, broad IAM, or unrelated storage policy. |
| [`modules/rule-groups`](modules/rule-groups) | Terraform or SecOps needs a typed rule boundary. | Group structure and, in Terraform mode, content. | Independent validation evidence and external live-content updates. |
| [`modules/policy-control`](modules/policy-control) | Policies require immutable promotion, observation, enforcement, or rollback. | STRICT\_ORDER policy releases and ARN bindings. | Rule content and remote metadata discovery. |
| [`modules/routes`](modules/routes) | Externally owned route tables need AZ-local endpoint routes. | Only declared `aws_route` resources. | Route tables, associations, endpoint lifecycle, or route discovery. |

## Rule-content ownership

| Model | Content owner | Terraform behavior | Choose it when |
|---|---|---|---|
| IaC pure | Reviewed Terraform security release | Plans structure and content drift. | Rule changes follow infrastructure review and release cadence. |
| AWS managed | AWS | Binds a managed STRICT\_ORDER ARN and caller-declared metadata. | AWS-maintained threat intelligence fits the policy. |
| Dynamic SecOps | SOC/SOAR through `UpdateRuleGroup` | Owns structure but ignores post-bootstrap content changes. | IOC/signature updates must move faster than infrastructure releases. |

Terraform validates attestation shape but cannot prove evidence independence.
Use a separately published manifest with its own digest or signature, bundle
digest, validation job and commit, and verify it in CI. See
[rule management](docs/rule-management.md) and the
[rule ownership diagram](docs/architecture/rule-management-models.md).

## Operational policy gate

`modules/policy-control` treats each key as an immutable release identity. Keep
candidate, active, and last-known-good policies simultaneously and bind the
firewall to the selected ARN.

| Mode | Effective intent | Required preparation |
|---|---|---|
| `observation` | Observe stateful detections without customer blocking behavior. | Managed groups may use `DROP_TO_ALERT`; blocking customer groups need an alert-only `observation_arn`. |
| `selective` | Enforce slots whose `enforce_from` threshold has been reached. | Explicit priorities, behavior metadata, and complete override coverage. |
| `enforce` | Enforce the selected policy's stateful blocking behavior. | Validated content, reviewed `HOME_NET`, monitoring, LKG, and a change window. |

Per-group incident overrides take precedence over incident-wide posture, which
takes precedence over `enforce_from`. Temporary posture requires `change_id`,
`owner`, and `expires_at`; Terraform does not auto-revert expired metadata.
Stateless rules remain enforced in every mode. See the
[policy release guide](docs/policy-releases-and-enforcement.md) and
[operations runbooks](docs/operations/README.md).

## Lifecycle and migration

| Change | Expected effect | Required action |
|---|---|---|
| Firewall key, created name, or VPC ID | Changes durable identity; VPC ID replaces the firewall. | Keep keys stable; use reviewed moves or a deliberate blue/green firewall. |
| Endpoint subnet or address family | Replaces the physical `vpce-*` for that AZ. | Wait for readiness, cut both route directions by AZ, and verify traffic. |
| Policy ARN, protections, analysis types, description, encryption, or tags | Provider-managed update with service-specific dataplane impact. | Review separately and use an appropriate change window. |
| Route table or destination | Replaces route identity. | Preserve caller keys and verify a single route owner. |

For migrations, save a complete plan and run:

```shell
terraform plan -out=migration.tfplan
./scripts/check-migration-plan.sh migration.tfplan approved-actions.txt
```

The guard always rejects delete and replace. See the
[2.0 upgrade guide](docs/UPGRADE-GUIDE-2.0.md).

## Documentation

- [Documentation map](docs/README.md) — choose a path by task or experience level.
- [Outputs and composition](docs/how-to-use-outputs.md) — Tier 1/2/3 contracts and recipes.
- [VPC v5 composition](docs/VPC-V5-COMPOSITION.md) — ownership and forward/return routing.
- [Rule management](docs/rule-management.md) — IaC, AWS-managed, and dynamic SecOps models.
- [Operations](docs/operations/README.md) — promotion, incident rollback, and hotfix runbooks.
- [Troubleshooting](docs/troubleshooting.md) and [FAQ](docs/faq.md).
- [Architecture diagrams](docs/architecture/README.md).
- [Architecture decisions](docs/adr/README.md) — decision status and delivery index.
- [2.0 upgrade guide](docs/UPGRADE-GUIDE-2.0.md) and [historical 1.0 upgrade](docs/UPGRADE-GUIDE-1.0.md).
- [Changelog](CHANGELOG.md), [contribution guide](CONTRIBUTING.md), and
  [security policy](SECURITY.md).

## Examples

| Example | Demonstrates | Validation boundary |
|---|---|---|
| [`basic`](examples/basic) | Existing VPC/policy, IPv4 firewall, stable endpoint outputs. | Placeholder IDs; static validation only until replaced. |
| [`end_to_end_vpc_v5`](examples/end\_to\_end\_vpc\_v5) | VPC v5, rule group, policy, firewall, routes, and CloudWatch logging. | CI rewrites the pre-release VPC source to a contract fixture; real traffic requires AWS acceptance. |
| [`centralized_without_egress_routes`](examples/centralized\_without\_egress\_routes) | TGW east-west route legs without NAT. | Existing TGW fabric and appliance mode are external. |
| [`centralized_with_egress_routes`](examples/centralized\_with\_egress\_routes) | TGW, firewall, NAT egress, and symmetric return routes. | Existing TGW/NAT/IGW fabric is external. |
| [`inject_existing_firewall`](examples/inject\_existing\_firewall) | Read-only firewall observation and readiness metadata. | Plan requires a real existing ARN unless mocked. |
| [`complete_logging`](examples/complete\_logging) | ALERT/FLOW/TLS destination ownership. | S3 and Firehose handles are placeholders. |
| [`complete_routes`](examples/complete\_routes) | External route-table bridge and AZ affinity. | Caller confirms exclusive route ownership. |
| [`rule_groups_suricata`](examples/rule\_groups\_suricata) | Typed sets, SID range, and attestation shape. | AWS remains the full Suricata parser. |
| [`policy_control_gate`](examples/policy\_control\_gate) | Candidate/active/LKG and incident precedence. | ARN metadata is caller-attested. |
| [`migration_pre_v1_routes`](examples/migration\_pre\_v1\_routes) | Historical route address chain. | Fixture state must be adapted, never applied unchanged. |

## Testing

```shell
terraform fmt -check -recursive
./scripts/check-docs.sh
./scripts/check-contract.sh
./scripts/validate-examples.sh
terraform test -no-color
tflint --init
tflint --recursive
./scripts/test-migration-plan-guard.sh
./scripts/test-policy-managed-override-mutation.sh
./scripts/test-product-moved-mutation.sh
```

---

## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.59, < 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.60.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_networkfirewall_firewall.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/networkfirewall_firewall) | resource |
| [terraform_data.firewall_contract](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.injected_endpoint_observation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [aws_networkfirewall_firewall.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/networkfirewall_firewall) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_firewalls"></a> [firewalls](#input\_firewalls) | Firewalls keyed by caller-controlled stable identity. Create mode owns the firewall; inject mode observes one by ARN. | <pre>map(object({<br/>    create = optional(bool, true)<br/>    arn    = optional(string)<br/><br/>    name        = optional(string)<br/>    description = optional(string)<br/>    policy_arn  = optional(string)<br/><br/>    placement = optional(object({<br/>      vpc = optional(object({<br/>        vpc_id = string<br/>        # Keys are caller-declared AWS Availability Zone names. Plan-time checks<br/>        # reject duplicate known AZ IDs, but cannot query unknown subnet metadata.<br/>        endpoint_subnets = map(object({<br/>          subnet_id            = string<br/>          availability_zone_id = optional(string)<br/>          ip_address_type      = optional(string, "IPV4")<br/>          # Prefer literal true. A computed unknown value defers this precondition to apply.<br/>          address_family_migration_ack = optional(bool, false)<br/>        }))<br/>      }))<br/>      transit_gateway = optional(object({<br/>        transit_gateway_id = string<br/>        availability_zones = map(object({<br/>          availability_zone_id = string<br/>        }))<br/>      }))<br/>    }))<br/><br/>    protections = optional(object({<br/>      delete                   = optional(bool, true)<br/>      policy_change            = optional(bool, true)<br/>      subnet_change            = optional(bool, true)<br/>      availability_zone_change = optional(bool, true)<br/>    }), {})<br/><br/>    enabled_analysis_types = optional(set(string), [])<br/><br/>    encryption = optional(object({<br/>      type    = optional(string, "AWS_OWNED_KMS_KEY")<br/>      key_arn = optional(string)<br/>    }), {})<br/><br/>    tags = optional(map(string), {})<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_aws_network_firewall"></a> [aws\_network\_firewall](#output\_aws\_network\_firewall) | DEPRECATED v1-compatible provider object when a created firewall uses key 'primary'; otherwise null. Use Tier 1 outputs. |
| <a name="output_firewall_arns"></a> [firewall\_arns](#output\_firewall\_arns) | Firewall ARNs by caller key. |
| <a name="output_firewall_ids"></a> [firewall\_ids](#output\_firewall\_ids) | Firewall IDs by caller key. |
| <a name="output_firewall_names"></a> [firewall\_names](#output\_firewall\_names) | Firewall names by caller key. |
| <a name="output_firewall_policy_arns"></a> [firewall\_policy\_arns](#output\_firewall\_policy\_arns) | Effective firewall policy ARNs by caller key. |
| <a name="output_resources"></a> [resources](#output\_resources) | Internal firewall resource and data-source collections. This shape is not semver-protected. |
| <a name="output_vpc_endpoint_ids_by_firewall_by_az"></a> [vpc\_endpoint\_ids\_by\_firewall\_by\_az](#output\_vpc\_endpoint\_ids\_by\_firewall\_by\_az) | VPC endpoint IDs by firewall key and input Availability Zone name. |
| <a name="output_vpc_endpoint_records_by_firewall_by_az"></a> [vpc\_endpoint\_records\_by\_firewall\_by\_az](#output\_vpc\_endpoint\_records\_by\_firewall\_by\_az) | VPC endpoint records by firewall key and input Availability Zone name, including AZ ID and readiness guarantee. |
<!-- END_TF_DOCS -->