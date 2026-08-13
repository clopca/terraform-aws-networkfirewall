variable "policies" {
  description = "Caller-keyed immutable policy releases. Keys end in -plain or -tls and are state identity; rule-group references bind ARNs and declared metadata, never content."
  nullable    = false
  type = map(object({
    create      = optional(bool, true)
    arn         = optional(string)
    name        = optional(string)
    description = optional(string)

    metadata = optional(object({
      rule_order  = string
      tls_enabled = bool
    }))

    enforcement = optional(object({
      mode = optional(string, "observation")
    }), {})

    incident_control = optional(object({
      mode            = optional(string, "normal")
      group_overrides = optional(map(string), {})
      change_id       = optional(string)
      owner           = optional(string)
      expires_at      = optional(string)
    }), {})

    home_net_cidrs = optional(set(string))

    stateful_rule_groups = optional(map(object({
      arn                    = string
      observation_arn        = optional(string)
      priority               = number
      kind                   = string
      rule_order             = string
      declared_capacity      = number
      enforce_from           = optional(string, "enforce")
      requires_home_net      = optional(bool, false)
      deep_threat_inspection = optional(string)
      behavior = object({
        actions             = set(string)
        has_terminal_action = bool
        override_coverage   = string
      })
    })), {})

    stateless_rule_groups = optional(map(object({
      arn               = string
      priority          = number
      declared_capacity = number
      always_enforced   = bool
    })), {})

    stream_exception_policy  = optional(string, "DROP")
    tcp_idle_timeout_seconds = optional(number, 350)

    tls = optional(object({
      inspection_configuration_arn = string
      enable_session_holding       = optional(bool, true)
    }))

    encryption = optional(object({
      type    = optional(string, "AWS_OWNED_KMS_KEY")
      key_arn = optional(string)
    }), {})

    tags = optional(map(string), {})
  }))
  default = {}
}
