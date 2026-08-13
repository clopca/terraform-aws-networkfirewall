variable "endpoint_ids_by_zone" {
  description = "Network Firewall endpoint IDs by the caller's stable zone key."
  type        = map(string)
  nullable    = false
}

variable "routes" {
  description = "Routes keyed by caller-controlled stable identity."
  nullable    = false

  type = map(object({
    route_table_id                   = string
    endpoint_zone_key                = string
    acknowledge_external_route_table = optional(bool, false)
    destination = object({
      ipv4_cidr      = optional(string)
      ipv6_cidr      = optional(string)
      prefix_list_id = optional(string)
    })
  }))

  default = {}
}
