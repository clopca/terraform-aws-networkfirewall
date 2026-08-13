# Observe an existing firewall

This example reads an existing AWS Network Firewall by ARN and publishes stable
Tier 1 identity, policy, endpoint, and readiness records. Use it when another
state or team owns firewall lifecycle and this configuration needs a normalized
read-only composition boundary.

## What this demonstrates

- `firewalls.primary.create = false` selects inject mode before the ARN is read.
- `firewalls.primary.arn` identifies the externally owned firewall without
  adopting or changing it.
- `firewall_arns.primary`, `firewall_ids.primary`, and `firewall_names.primary`
  expose stable scalar identity by caller key.
- `firewall_policy_arns.primary` reports the observed policy binding without
  taking policy ownership.
- `vpc_endpoint_ids_by_firewall_by_az.primary` preserves AWS Availability Zone
  names for route consumers.
- `vpc_endpoint_records_by_firewall_by_az.primary` marks readiness as unverified
  because a data source cannot provide create-resource attachment guarantees.

External routes must already send forward and return traffic through the same
endpoint AZ. Inject mode observes that topology; it does not validate or manage
it.

## Relevant configuration

The complete deployable configuration is in [`main.tf`](./main.tf). The inject
boundary and normalized output are the distinguishing portions:

```hcl
firewalls = {
  primary = {
    create = false
    arn    = var.existing_firewall_arn
  }
}
```

```hcl
output "observed_firewall" {
  value = {
    arn                = module.network_firewall.firewall_arns.primary
    id                 = module.network_firewall.firewall_ids.primary
    name               = module.network_firewall.firewall_names.primary
    policy_arn         = module.network_firewall.firewall_policy_arns.primary
    endpoints_by_az    = module.network_firewall.vpc_endpoint_ids_by_firewall_by_az.primary
    endpoint_readiness = module.network_firewall.vpc_endpoint_records_by_firewall_by_az.primary
  }
}
```

## Prerequisites and cost

- Replace the placeholder ARN with a firewall in the configured account and
  Region and grant read permissions.
- Record the external owners of the firewall, policy, rules, logging, and routes.
- This example creates no resources, but the observed firewall continues to
  incur endpoint and traffic-processing charges.

## Run

```shell
terraform init
terraform validate
terraform plan
```

After plan, compare the observed VPC, policy, AZ set, and endpoint IDs with live
AWS state and external routes. Verify `SyncStates`, attachment health, logging,
and both traffic directions operationally; static validation cannot do so.
