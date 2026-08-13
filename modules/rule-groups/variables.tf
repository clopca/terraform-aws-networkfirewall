variable "rule_groups" {
  description = "Caller-keyed rule-group releases. Created groups use exactly one closed source lane; injected groups require declared metadata because the AWS provider has no rule-group data source."
  nullable    = false
  type = map(object({
    create             = optional(bool, true)
    arn                = optional(string)
    name               = optional(string)
    description        = optional(string)
    type               = optional(string)
    capacity           = optional(number)
    rule_order         = optional(string, "STRICT_ORDER")
    content_management = optional(string, "terraform")

    metadata = optional(object({
      type              = string
      rule_order        = string
      declared_capacity = number
      kind              = string
    }))

    ip_sets            = optional(map(set(string)), {})
    port_sets          = optional(map(set(string)), {})
    required_ip_sets   = optional(set(string), [])
    required_port_sets = optional(set(string), [])
    requires_home_net  = optional(bool, false)

    sid_range = optional(object({
      min = number
      max = number
    }))

    source = optional(object({
      rules_string = optional(string)
      rules_source_list = optional(object({
        generated_rules_type = string
        target_types         = set(string)
        targets              = set(string)
      }))
      stateful_rules = optional(map(object({
        action = string
        header = object({
          protocol         = string
          source           = string
          source_port      = string
          direction        = string
          destination      = string
          destination_port = string
        })
        options = map(object({
          keyword  = string
          settings = optional(set(string), [])
        }))
      })))
      stateless_rules = optional(map(object({
        priority = number
        actions  = set(string)
        match = object({
          sources      = optional(set(string), [])
          destinations = optional(set(string), [])
          source_ports = optional(set(object({
            from = number
            to   = number
          })), [])
          destination_ports = optional(set(object({
            from = number
            to   = number
          })), [])
          protocols = optional(set(number), [])
          tcp_flags = optional(set(object({
            flags = set(string)
            masks = optional(set(string), [])
          })), [])
        })
      })))
    }))

    source_validation = optional(object({
      mode          = string
      manifest_uri  = optional(string)
      bundle_sha256 = optional(string)
    }))

    encryption = optional(object({
      type    = optional(string, "AWS_OWNED_KMS_KEY")
      key_arn = optional(string)
    }), {})

    tags = optional(map(string), {})
  }))
  default = {}
}
