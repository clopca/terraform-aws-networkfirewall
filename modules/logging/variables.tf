variable "logging_configurations" {
  description = "Logging configurations keyed by caller-controlled stable identity."
  nullable    = false

  type = map(object({
    enabled              = optional(bool, true)
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
