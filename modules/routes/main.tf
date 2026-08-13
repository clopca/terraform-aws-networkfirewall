resource "terraform_data" "route_contract" {
  for_each = var.routes

  input = each.key

  lifecycle {
    precondition {
      condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9_.-]*$", each.key))
      error_message = "Route key '${each.key}' is invalid. Use letters, numbers, '.', '_', or '-' and do not include '/'."
    }

    precondition {
      condition     = each.value.acknowledge_external_route_table
      error_message = "Route '${each.key}' targets an externally owned route table. Set acknowledge_external_route_table=true after confirming this module is the only owner of that route-table/destination entry."
    }

    precondition {
      condition     = contains(keys(var.vpc_endpoint_ids_by_az), each.value.availability_zone)
      error_message = "Route '${each.key}' references availability_zone '${each.value.availability_zone}', which is absent from vpc_endpoint_ids_by_az. Add that zone or correct the route."
    }

    precondition {
      condition = length(compact([
        each.value.destination.ipv4_cidr != null ? "ipv4" : "",
        each.value.destination.ipv6_cidr != null ? "ipv6" : "",
        each.value.destination.prefix_list_id != null ? "prefix-list" : "",
      ])) == 1
      error_message = "Route '${each.key}' must set exactly one destination: ipv4_cidr, ipv6_cidr, or prefix_list_id."
    }

    precondition {
      condition     = each.value.destination.prefix_list_id == null
      error_message = "Route '${each.key}' uses prefix_list_id, but AWS provider 6.59 conflicts destination_prefix_list_id with vpc_endpoint_id. Expand the prefix list to caller-keyed CIDR routes instead."
    }

    precondition {
      condition = (
        each.value.destination.ipv4_cidr == null || (
          can(cidrhost(each.value.destination.ipv4_cidr, 0)) && !strcontains(each.value.destination.ipv4_cidr, ":")
        )
        ) && (
        each.value.destination.ipv6_cidr == null || (
          can(cidrhost(each.value.destination.ipv6_cidr, 0)) && strcontains(each.value.destination.ipv6_cidr, ":")
        )
        ) && (
        each.value.destination.prefix_list_id == null || can(regex("^pl-[0-9a-f]+$", each.value.destination.prefix_list_id))
      )
      error_message = "Route '${each.key}' has an invalid destination family or prefix list ID. Put IPv4 in ipv4_cidr, IPv6 in ipv6_cidr, or use a pl-... prefix_list_id."
    }

    precondition {
      condition = length([
        for other_key, other in var.routes : other_key
        if other_key != each.key &&
        other.route_table_id == each.value.route_table_id &&
        jsonencode(other.destination) == jsonencode(each.value.destination)
      ]) == 0
      error_message = "Route '${each.key}' duplicates another route-table/destination combination. Keep one caller key for each unique combination."
    }
  }
}

resource "aws_route" "this" {
  for_each = {
    for key, route in var.routes : key => route if route.destination.prefix_list_id == null
  }

  route_table_id              = each.value.route_table_id
  destination_cidr_block      = each.value.destination.ipv4_cidr
  destination_ipv6_cidr_block = each.value.destination.ipv6_cidr
  vpc_endpoint_id             = lookup(var.vpc_endpoint_ids_by_az, each.value.availability_zone, "vpce-invalid")

  depends_on = [terraform_data.route_contract]
}
