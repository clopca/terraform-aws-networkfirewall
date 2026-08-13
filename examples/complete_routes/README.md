# AZ-local routes in external route tables

This example creates a two-AZ firewall and composes its endpoint map into two
routes in externally owned workload route tables. Use it when firewall placement
and endpoint lifecycle belong to this state but route-table lifecycle remains in
a VPC or network-foundation state.

## What this demonstrates

- `vpc_endpoint_ids_by_firewall_by_az.primary` passes one endpoint ID per real
  Availability Zone to `modules/routes`.
- `routes.workload-a-default.availability_zone = "us-east-1a"` selects the
  endpoint for route table A rather than relying on list order.
- `routes.workload-b-default.availability_zone = "us-east-1b"` provides the
  equivalent independent route identity for AZ B.
- `destination.ipv4_cidr = "0.0.0.0/0"` creates an IPv4 default route in each
  declared external table.
- `acknowledge_external_route_table = true` records the caller's ownership
  assertion; it does not discover competing state.
- `route_ids` returns stable route handles keyed by the caller's route keys.

Each workload route sends outbound traffic to its AZ-local endpoint. The
post-firewall route and the reverse route back through that same endpoint remain
external and must be validated separately.

## Relevant configuration

The complete deployable configuration is in [`main.tf`](./main.tf). The external
route-table composition is the distinguishing portion:

```hcl
vpc_endpoint_ids_by_az = module.network_firewall.vpc_endpoint_ids_by_firewall_by_az.primary

routes = {
  workload-a-default = {
    route_table_id                   = "rtb-01111111111111111"
    availability_zone                = "us-east-1a"
    acknowledge_external_route_table = true
    destination                      = { ipv4_cidr = "0.0.0.0/0" }
  }
  workload-b-default = {
    route_table_id                   = "rtb-02222222222222222"
    availability_zone                = "us-east-1b"
    acknowledge_external_route_table = true
    destination                      = { ipv4_cidr = "0.0.0.0/0" }
  }
}
```

## Prerequisites and cost

- Replace every VPC, subnet, policy, and route-table identifier before planning.
- Confirm no other Terraform state owns either route-table/destination pair.
- Define post-firewall and return routes for both AZs before cutover.
- Applying creates two billable firewall endpoints and two routes; Network
  Firewall processing and data-transfer charges can apply.

## Run

```shell
terraform init
terraform validate
terraform plan -out=tfplan
```

After apply, wait for both endpoint attachments and run forward, return,
allowed, and denied probes in each AZ. Static validation does not prove exclusive
route ownership, endpoint readiness, or traffic symmetry.
