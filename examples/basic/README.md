# Dual-stack firewall in an existing VPC

This example creates one protected AWS Network Firewall across two existing
subnets. Use it when the VPC, firewall policy, and forward and return routes are
owned outside this configuration but firewall endpoint identity should remain
stable by Availability Zone.

## What this demonstrates

- `firewalls.primary` is the caller-owned key for the firewall state identity.
- `firewalls.primary.placement.vpc.vpc_id` selects the existing VPC without
  transferring VPC ownership.
- `endpoint_subnets[az].subnet_id` binds one existing firewall subnet to each
  real Availability Zone name.
- `endpoint_subnets[az].ip_address_type = "DUALSTACK"` creates dual-stack
  endpoint mappings.
- `endpoint_subnets[az].address_family_migration_ack = true` acknowledges that
  both mappings are new dual-stack identities; it is not permission to replace
  an existing mapping in place.
- `vpc_endpoint_ids_by_firewall_by_az.primary` preserves AZ keys for downstream
  route composition.

Source-subnet routes must select the endpoint in their own AZ. Allowed traffic
then follows externally owned post-firewall routing, and the return path must
traverse the same AZ-local endpoint before reaching the source.

## Relevant configuration

The complete deployable configuration is in [`main.tf`](./main.tf). The firewall
placement is the distinguishing portion:

```hcl
firewalls = {
  primary = {
    name        = "example-inspection"
    description = "Network inspection firewall"
    policy_arn  = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/example"
    placement = {
      vpc = {
        vpc_id = "vpc-0123456789abcdef0"
        endpoint_subnets = {
          "us-east-1a" = {
            subnet_id                    = "subnet-01111111111111111"
            ip_address_type              = "DUALSTACK"
            address_family_migration_ack = true
          }
          "us-east-1b" = {
            subnet_id                    = "subnet-02222222222222222"
            ip_address_type              = "DUALSTACK"
            address_family_migration_ack = true
          }
        }
      }
    }
    tags = { Environment = "example" }
  }
}
```

## Prerequisites and cost

- Replace the VPC, subnet, and policy identifiers before planning.
- Both subnets must support the requested address family and be dedicated to
  Network Firewall endpoint placement.
- Applying creates two billable Network Firewall endpoints plus traffic
  processing charges. Routes and logging are not created by this example.

## Run

```shell
terraform init
terraform validate
terraform plan -out=tfplan
```

Before apply, confirm that neither AZ key replaces an existing mapping and that
both traffic directions are defined externally. Static validation does not
confirm resource existence, endpoint readiness, or dataplane symmetry.
