# Centralized inspection without internet egress

This example creates a two-AZ firewall and the VPC route legs for centralized
east-west inspection through an existing Transit Gateway. Use it when the TGW,
appliance-mode attachment, inspection VPC, and spoke routing already exist and
this state owns only the firewall plus selected VPC routes.

## What this demonstrates

- `endpoint_subnet_ids_by_az` binds one firewall subnet to each selected AZ.
- `tgw_attachment_route_table_ids_by_az` identifies external attachment-subnet
  route tables without adopting their lifecycle.
- `routes_to_firewall.routes` creates one caller-keyed spoke route per AZ and
  uses `availability_zone` to select the local endpoint.
- `destination.ipv4_cidr = local.spoke_cidr` models the reviewed spoke inventory
  used in both directions.
- `acknowledge_external_route_table = true` records exclusive route ownership
  outside the submodule.
- `aws_route.firewall_to_tgw` sends inspected spoke traffic from each firewall
  subnet route table back to the TGW.

Spoke traffic arrives through the TGW attachment in the selected appliance-mode
AZ, traverses that AZ's firewall endpoint, and returns to the TGW for the
destination spoke. The reverse flow must use the same attachment and endpoint AZ.

## Relevant configuration

The complete deployable configuration is in [`main.tf`](./main.tf). The two
inspection route legs are the distinguishing portion:

```hcl
routes = {
  for az, route_table_id in local.tgw_attachment_route_table_ids_by_az :
  "tgw_${replace(az, "-", "_")}_spokes" => {
    route_table_id                   = route_table_id
    destination                      = { ipv4_cidr = local.spoke_cidr }
    availability_zone                = az
    acknowledge_external_route_table = true
  }
}
```

```hcl
resource "aws_route" "firewall_to_tgw" {
  for_each = local.firewall_route_table_ids_by_az

  route_table_id         = each.value
  destination_cidr_block = local.spoke_cidr
  transit_gateway_id     = var.transit_gateway_id
}
```

## Prerequisites and cost

- Replace every VPC, subnet, route-table, TGW, policy, and CIDR placeholder.
- The existing TGW attachment must use appliance mode with reviewed route-table
  associations and propagations.
- Confirm one state owner for each route-table/destination pair.
- Applying creates two billable firewall endpoints and VPC routes; TGW,
  Network Firewall, transfer, and cross-AZ processing charges can apply.

## Run

```shell
terraform init
terraform validate
terraform plan -out=tfplan
```

After apply, verify endpoint and attachment health, allowed and denied
spoke-to-spoke flows, management paths, logging, and same-AZ return traffic.
Static validation does not prove TGW policy, route ownership, or symmetry.
