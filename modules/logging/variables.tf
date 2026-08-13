variable "logging_configurations" {
  description = "Logging configurations keyed by caller identity. manage=false deletes the effective logging configuration. Changing monitoring_dashboard temporarily removes and reinstalls all destinations in provider 6.60."
  nullable    = false

  type = map(object({
    manage               = optional(bool, true)
    firewall_arn         = string
    monitoring_dashboard = optional(bool, false)

    logs = map(object({
      log_type = string
      destination = object({
        cloudwatch = optional(object({
          create            = optional(bool, true)
          log_group_name    = string
          retention_in_days = optional(number, 30)
          kms_key_arn       = optional(string)
          tags              = optional(map(string), {})
        }))
        s3 = optional(object({
          bucket_name = string
          prefix      = optional(string)
        }))
        firehose = optional(object({
          delivery_stream_name = string
        }))
      })
    }))
  }))

  default = {}
}
