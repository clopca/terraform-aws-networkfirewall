variable "firewalls" {
  description = "Firewalls keyed by caller-controlled stable identity. Create mode owns the firewall; inject mode observes one by ARN."
  nullable    = false

  type = map(object({
    create = optional(bool, true)
    arn    = optional(string)

    name        = optional(string)
    description = optional(string)
    policy_arn  = optional(string)

    placement = optional(object({
      vpc = optional(object({
        vpc_id = string
        endpoint_subnets = map(object({
          subnet_id            = string
          availability_zone_id = optional(string)
          ip_address_type      = optional(string, "IPV4")
        }))
      }))
      transit_gateway = optional(object({
        transit_gateway_id = string
        availability_zones = map(object({
          availability_zone_id = string
        }))
      }))
    }))

    protections = optional(object({
      delete                   = optional(bool, true)
      policy_change            = optional(bool, true)
      subnet_change            = optional(bool, true)
      availability_zone_change = optional(bool, true)
    }), {})

    enabled_analysis_types = optional(set(string), [])

    encryption = optional(object({
      type    = optional(string, "AWS_OWNED_KMS_KEY")
      key_arn = optional(string)
    }), {})

    tags = optional(map(string), {})
  }))

  default = {}
}
