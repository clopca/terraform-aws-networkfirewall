# Centralized inspection with internet egress

This example creates a two-AZ firewall and the VPC route legs for centralized
TGW internet egress through existing zonal NAT Gateways and an Internet Gateway.
Use it when the network foundation owns the inspection VPC, TGW attachment,
subnets, gateways, and route tables while this state owns selected routes.

## What this demonstrates

- `routes_to_firewall.routes` merges TGW attachment defaults and NAT-subnet spoke
  return routes under stable caller keys.
- `availability_zone = az` selects the Network Firewall endpoint matching each
  external route table's AZ.
- `aws_route.firewall_to_nat` sends allowed outbound traffic to the AZ-local NAT
  Gateway after inspection.
- `aws_route.firewall_to_tgw` sends inspected return traffic for
  `local.spoke_cidr` back to the TGW.
- `aws_route.nat_to_internet` supplies the NAT subnet default route to the
  existing Internet Gateway.
- `acknowledge_external_route_table = true` asserts exclusive ownership of the
  two endpoint-target route families.

Spoke traffic arrives through the TGW attachment in the selected appliance-mode
AZ, traverses the AZ-local endpoint, and exits through the AZ-local NAT Gateway.
Return traffic reaches that NAT Gateway, follows the spoke CIDR through the same
endpoint, and returns through the TGW.

## Relevant configuration

The complete deployable configuration is in [`main.tf`](./main.tf). The endpoint
route families are the distinguishing portion:

```hcl
routes = merge(
  {
    for az, route_table_id in local.tgw_attachment_route_table_ids_by_az :
    "tgw_${replace(az, "-", "_")}_default" => {
      route_table_id                   = route_table_id
      destination                      = { ipv4_cidr = "0.0.0.0/0" }
      availability_zone                = az
      acknowledge_external_route_table = true
    }
  },
  {
    for az, route_table_id in local.nat_route_table_ids_by_az :
    "nat_${replace(az, "-", "_")}_spoke_return" => {
      route_table_id                   = route_table_id
      destination                      = { ipv4_cidr = local.spoke_cidr }
      availability_zone                = az
      acknowledge_external_route_table = true
    }
  }
)
```

## Prerequisites and cost

- Replace every VPC, subnet, route-table, NAT, IGW, TGW, policy, and CIDR value.
- The TGW attachment must use appliance mode; NAT Gateways must be zonal and
  aligned with the route-table maps.
- Confirm exclusive ownership for every route-table/destination pair.
- Applying creates two firewall endpoints and routes. Existing NAT, TGW,
  Network Firewall, log, processing, transfer, and cross-AZ charges can apply.

## Run

```shell
terraform init
terraform validate
terraform plan -out=tfplan
```

After apply, verify the observed NAT source address, both endpoint attachments,
allowed and denied flows, logging, and same-AZ return paths. Static validation
does not prove TGW policy, route ownership, or dataplane symmetry.
