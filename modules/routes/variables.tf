variable "vpc_endpoint_ids_by_az" {
  description = "Network Firewall endpoint IDs by the caller's stable zone key."
  type        = map(string)
  nullable    = false
}

variable "routes" {
  description = "Routes keyed by caller-controlled stable identity."
  nullable    = false

  type = map(object({
    # Physical route identity (ForceNew) is route_table_id plus destination.
    route_table_id = string
    destination = object({
      ipv4_cidr      = optional(string)
      ipv6_cidr      = optional(string)
      prefix_list_id = optional(string)
    })

    # The selected VPC endpoint target is mutable through EC2 ReplaceRoute.
    availability_zone                = string
    acknowledge_external_route_table = optional(bool, false)
  }))

  default = {}
}
