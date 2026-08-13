# Composing with the AWS IA VPC v5 contract

## Prerequisite

Use this pattern only with a VPC module release that publishes `vpc_id` and `subnet_ids_by_group_by_az` and supports a caller-defined `firewall` subnet group. If that contract is not available in the published VPC version you consume, use the neutral `vpc_id` and `endpoint_subnet_ids_by_az` variables from the root quick start instead.

```hcl
module "network_firewall" {
  source  = "aws-ia/networkfirewall/aws"
  version = "~> 2.0"

  firewalls = {
    primary = {
      name       = "inspection"
      policy_arn = var.firewall_policy_arn
      placement = { vpc = {
        vpc_id = module.vpc.vpc_id
        endpoint_subnets = {
          for availability_zone, subnet_id in module.vpc.subnet_ids_by_group_by_az.firewall :
          availability_zone => {
            subnet_id       = subnet_id
            ip_address_type = "IPV4"
          }
        }
      } }
    }
  }
}
```

For dual stack, first confirm that every firewall subnet has the required IPv6 association. Set `ip_address_type = "DUALSTACK"` and `address_family_migration_ack = true` only for new blue/green mappings. Do not flip an existing firewall/AZ key in place.

Route tables remain caller-owned. Compose `modules/routes` with `module.network_firewall.vpc_endpoint_ids_by_firewall_by_az.primary`, use the route's real AZ, and set `acknowledge_external_route_table = true` only after confirming no other Terraform state owns the same route-table/destination pair. See the executable `complete_routes` example.
