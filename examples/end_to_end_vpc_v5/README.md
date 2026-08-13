# End-to-end VPC v5 inspection

This example composes AWS IA VPC v5 with a rule group, immutable policy,
two-AZ Network Firewall, native AZ-local routes, and ALERT/FLOW CloudWatch
logging. Use it as the complete path when one configuration owns the inspection
VPC and all Network Firewall composition boundaries.

## What this demonstrates

- `subnets.firewall.routing.nat_gateway = true` sends allowed inspected traffic
  to the AZ-local NAT Gateway.
- `routes.application_default.target.ids_by_az` sends each application default
  route to the firewall endpoint with the same AZ key.
- The two `public_application_return_*` routes cover both application subnet
  CIDRs and return traffic through the AZ-local firewall endpoint before
  VPC-local delivery.
- `rule_groups.egress-v1` creates an attested, alert-only STRICT_ORDER rule
  release with `requires_home_net = true`.
- `rule_group_records = module.rule_groups.rule_group_records` carries typed
  identity and HOME_NET metadata into policy control.
- `policies.active-2026-08-13-plain.enforcement.mode = "observation"` creates
  the policy ARN bound by `firewalls.primary.policy_arn`.
- `logging_configurations.primary.logs` enables ALERT and FLOW CloudWatch
  destinations for the created firewall.

In each AZ, application traffic traverses the AZ-local firewall endpoint and
exits through the AZ-local NAT Gateway. Return traffic reaches that NAT Gateway,
uses an exact application-subnet CIDR route through the same endpoint, and then
follows the VPC local route to the workload.

AWS requires routes more specific than the VPC local route that target a
firewall endpoint to exactly match a subnet CIDR block. Do not aggregate adjacent
application subnets into one return route. This requirement is validated by a
real AWS apply; AWS rejects an aggregate that spans multiple subnets.

With `netmask = 24` and `cidr_index = 10`, VPC v5 reserves six AZ slots and
assigns the first two application subnets `10.20.60.0/24` and
`10.20.61.0/24`.

## Relevant configuration

The complete deployable configuration is in [`main.tf`](./main.tf). The native
forward and return route composition is the distinguishing portion:

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
  public_application_return_us_east_1a = {
    from_group  = "public"
    destination = { type = "ipv4_cidr", value = "10.20.60.0/24" }
    target = {
      type      = "vpc_endpoint"
      ids_by_az = module.network_firewall.vpc_endpoint_ids_by_firewall_by_az.primary
    }
  }
  public_application_return_us_east_1b = {
    from_group  = "public"
    destination = { type = "ipv4_cidr", value = "10.20.61.0/24" }
    target = {
      type      = "vpc_endpoint"
      ids_by_az = module.network_firewall.vpc_endpoint_ids_by_firewall_by_az.primary
    }
  }
}
```

The firewall consumes the VPC subnet map directly:

```hcl
endpoint_subnets = {
  for az, subnet_id in module.vpc.subnet_ids_by_group_by_az.firewall :
  az => { subnet_id = subnet_id }
}
```

## Validation evidence

The end-to-end composition has been validated with a real AWS apply: inspected
HTTP and HTTPS traffic completed successfully, a custom Suricata alert appeared
in CloudWatch, flow evidence confirmed zonal affinity, and the converged
configuration produced an empty subsequent plan.

## Prerequisites and cost

- VPC v5 must be available from the configured source. Repository validation
  substitutes the checked-in contract fixture until the Registry release exists.
- Replace validation evidence, account-specific values, CIDRs, and Region before
  planning an apply.
- Applying creates two firewall endpoints, two NAT Gateways, a rule group, a
  policy, and CloudWatch logs, with hourly, processing, retention, and transfer
  charges.

## Run

```shell
../../scripts/validate-examples.sh
```

For a real deployment, run `terraform init`, `terraform validate`, and a saved
plan from a copied configuration with an available VPC source. After apply,
verify both endpoint attachments, log delivery, allowed and denied traffic, and
same-AZ return paths. Static validation proves only contract compatibility.
