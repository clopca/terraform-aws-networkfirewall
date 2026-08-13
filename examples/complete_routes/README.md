# Complete routes composition

Creates a two-AZ IPv4 firewall and composes its Tier 1 endpoint map into `modules/routes`. Each workload route selects the endpoint in the same Availability Zone and explicitly acknowledges that the route table is externally owned.

Replace every illustrative ID/ARN before apply. Confirm that no other Terraform state owns either `route_table_id + destination` identity; `acknowledge_external_route_table = true` is a responsibility boundary, not discovery.
