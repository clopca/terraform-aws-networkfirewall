# Security and operations

Firewall protections, encryption, logging, rule validation, route ownership, and
incident posture are independently owned. A complete deployment assigns one
owner to each boundary and verifies both traffic directions; a successful
Terraform apply establishes configuration, not dataplane correctness.

## Create and inject ownership

Root lifecycle mode is plan-known:

- `create = true` owns the firewall resource and requires `name`, `policy_arn`,
  and placement while forbidding `arn`;
- `create = false` observes an existing firewall by `arn` and forbids managed
  create-mode fields;
- inject mode does not adopt protections, policy binding, endpoint mappings,
  encryption, tags, or deletion lifecycle.

```hcl
firewalls = {
  primary = {
    create = false
    arn    = var.existing_firewall_arn
  }
}
```

The same rule applies to rule groups and policies: injection supplies an ARN and
declared metadata but preserves the external lifecycle owner. Logging and route
submodules do not inject their primary resources; they own the explicitly
selected logging configuration or route resources while their destinations and
route tables remain external.

## Firewall protections

Created firewalls enable all four protections by default:

```hcl
protections = {
  delete                   = true
  policy_change            = true
  subnet_change            = true
  availability_zone_change = true
}
```

| Protection | Change controlled |
| --- | --- |
| `delete` | Firewall deletion. |
| `policy_change` | Binding a different firewall policy ARN. |
| `subnet_change` | Adding, removing, or replacing VPC endpoint subnet mappings. |
| `availability_zone_change` | Changing the selected availability-zone set. |

A protection is a service-side safety control, not a release workflow. If an
approved change requires disabling one, separate the protection change from the
functional change when practical, record the rollback, and restore the intended
protection immediately after verification. Never disable all protections merely
to make a plan apply.

Inject mode observes the live protection state but cannot promise or manage it.
The external firewall owner must provide equivalent change controls.

## Endpoint replacement boundary

Firewall/AZ map keys identify logical endpoint mappings. Changing
`subnet_id` or `ip_address_type` for an existing key replaces the physical
`vpce-*` attachment for that AZ.

Use a blue/green mapping when possible. `address_family_migration_ack = true`
acknowledges a reviewed non-IPv4 mapping or family transition; it does not make
in-place replacement safe. Prefer a literal value because a computed unknown can
defer the precondition until apply.

Before route cutover:

1. verify the requested AZ set and subnet family;
2. wait for every attachment to report ready;
3. compare endpoint IDs with route targets by AZ;
4. confirm ALERT/FLOW logging health;
5. test allowed, denied, management, and return traffic;
6. retain the previous symmetric route path until the observation interval ends.

## Encryption and analysis

Firewall encryption defaults to the AWS-owned key:

```hcl
encryption = {
  type = "AWS_OWNED_KMS_KEY"
}
```

Customer-managed KMS requires `type = "CUSTOMER_KMS"` and `key_arn`. Review key
policy, grants, Region, deletion protection, rotation, and owner before apply.
Changing the encryption contract can affect service operations and must not be
combined casually with endpoint or policy cutover.

`enabled_analysis_types` enables Network Firewall analysis features supported by
the provider. Treat additions and removals as operational changes: review service
cost, telemetry, IAM, and result consumers, and verify expected analysis output
after apply.

Rule groups and policy releases expose their own encryption objects. Keep KMS
ownership explicit for each resource family; a root firewall key does not
implicitly encrypt rule groups, policies, or log destinations.

## Logging ownership

`modules/logging` owns one effective Network Firewall logging configuration per
firewall ARN. All selected ALERT, FLOW, and TLS destinations belong under one
caller key:

```hcl
logging_configurations = {
  primary = {
    firewall_arn         = module.network_firewall.firewall_arns.primary
    monitoring_dashboard = true
    logs = {
      alert = {
        log_type = "ALERT"
        destination = {
          cloudwatch = {
            log_group_name    = "/aws/network-firewall/inspection/alert"
            retention_in_days = 365
            kms_key_arn       = aws_kms_key.logs.arn
          }
        }
      }
      flow = {
        log_type = "FLOW"
        destination = {
          s3 = {
            bucket_name = var.audit_bucket_name
            prefix      = "network-firewall/flow"
          }
        }
      }
    }
  }
}
```

Destination ownership is explicit:

| Destination | Ownership contract |
| --- | --- |
| CloudWatch Logs | The submodule can create or reference the named log group and manages retention, optional KMS, and tags only in create mode. |
| Amazon S3 | Bucket, policy, encryption, retention, object lock, and lifecycle remain external; supply the bucket name and optional prefix. |
| Kinesis Data Firehose | Delivery stream and its IAM/S3 dependencies remain external; supply the stream name. |

One firewall ARN cannot appear under multiple logging configuration keys.
`manage = false` removes the effective logging configuration from Terraform; it
is not a pause switch. Changing `monitoring_dashboard` with AWS provider 6.60 can
temporarily remove and reinstate destinations, so use a change window and verify
all deliveries afterward.

Keep logging enabled during policy promotion and incidents. Removing visibility
while behavior is uncertain prevents safe diagnosis and rollback.

## Rule and policy evidence

Terraform validates rule structure, declared metadata, quotas, and evidence
shape. It cannot prove that a manifest is independent, an external ARN serves the
attested content, or a SOC update was authorized.

A security release record should include:

- bundle and manifest digests or signature;
- immutable source/build identity and AWS parser context;
- rule-group ARN, type, rule order, capacity, and ownership model;
- policy release ARN and `effective_releases` output;
- HOME_NET, TLS, engine options, and incident posture;
- match/no-match plus forward/reverse traffic evidence;
- owner, approval, observation interval, and rollback ARN/bundle.

See [rule management](rule-management.md) and
[policy control](policy-control.md) for the concrete contracts.

## Route and readiness evidence

`vpc_endpoint_records_by_firewall_by_az` distinguishes managed and observed
readiness. `provider_waited` and `observed_ready` are configuration-level signals;
`unverified` requires direct AWS checks before cutover. None proves traffic.

For every selected AZ, record:

- endpoint ID, subnet ID, AZ name/ID, family, and attachment status;
- source route table and same-AZ endpoint target;
- post-firewall next hop;
- destination-side return route to the same endpoint;
- positive, negative, management, DNS, identity, and time probes;
- ALERT/FLOW/TLS evidence for the exact flow tuple.

TGW centralized inspection additionally requires appliance mode and reviewed TGW
route-table associations and propagations. The VPC module cannot establish those
external TGW policies.

## Plan and apply controls

Save a plan for every production change:

```shell
terraform plan -out=tfplan
terraform show -no-color tfplan > tfplan.txt
```

For v1/pre-v1 migration, also run:

```shell
./scripts/check-migration-plan.sh tfplan approved-actions.txt
```

The migration guard rejects delete and replace and requires exact approval for
create, update, and forget. For normal releases, review at least:

- firewall replacement and endpoint subnet/family changes;
- protection disablement;
- policy ARN, rule-group ARN, HOME_NET, TLS, and engine changes;
- logging destination removal or dashboard toggles;
- route-table/destination replacement or duplicate ownership;
- deletion of candidate, active, LKG, or rollback rule groups.

Stop when the plan includes an unrelated resource family, an unreviewed
replacement, missing logging, absent LKG, or an AZ whose endpoint is not ready.

## Runbook selection

Use the smallest runbook that matches the task:

| Task | Runbook |
| --- | --- |
| Move a validated candidate from observation to enforcement | [Promote to enforce](operations/promote-to-enforce.md) |
| Reduce harmful stateful behavior or return to an LKG policy | [Incident control and rollback](operations/incident-control-and-rollback.md) |
| Publish one urgent detection or blocking correction | [Emergency rule hotfix](operations/rule-hotfix.md) |

Temporary incident controls require `change_id`, `owner`, and `expires_at`.
Expiry is not automatic; monitor it externally and apply an explicit return to
normal.

## Operational checklist

- Assign one lifecycle owner to every firewall, rule group, policy, route,
  logging configuration, and durable log destination.
- Keep protections enabled except for a narrow, reviewed change.
- Treat endpoint subnet or address-family changes as physical replacement.
- Keep ALERT/FLOW and applicable TLS logging healthy during all changes.
- Verify each AZ attachment and both traffic directions before cutover.
- Retain candidate, active, and LKG policy/rule releases through the rollback
  window.
- Monitor incident-control expiry and remove temporary posture deliberately.
- Include Network Firewall endpoint/processing, NAT, TGW, logs, KMS, Firehose,
  S3, public IPv4, and cross-AZ transfer in operating estimates.
