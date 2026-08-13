locals {
  terraform_content_groups = {
    for key, group in var.rule_groups : key => group
    if group.create && group.content_management == "terraform"
  }
  external_content_groups = {
    for key, group in var.rule_groups : key => group
    if group.create && group.content_management == "external"
  }

  source_lanes = {
    for key, group in var.rule_groups : key => compact([
      try(group.source.rules_string, null) != null ? "rules_string" : "",
      try(group.source.rules_source_list, null) != null ? "rules_source_list" : "",
      try(group.source.stateful_rules, null) != null ? "stateful_rules" : "",
      try(group.source.stateless_rules, null) != null ? "stateless_rules" : "",
    ])
  }

  sid_values = {
    for key, group in var.rule_groups : key => [
      for sid in flatten(regexall("(?i)sid\\s*:\\s*([0-9]+)\\s*;", try(group.source.rules_string, null) == null ? "" : group.source.rules_string)) : tonumber(sid)
    ]
  }

  missing_ip_sets = {
    for key, group in var.rule_groups : key => setsubtract(
      group.required_ip_sets,
      toset([for set_key, values in group.ip_sets : set_key if length(values) > 0]),
    )
  }
  missing_port_sets = {
    for key, group in var.rule_groups : key => setsubtract(
      group.required_port_sets,
      toset([for set_key, values in group.port_sets : set_key if length(values) > 0]),
    )
  }
}

resource "terraform_data" "rule_group_contract" {
  for_each = var.rule_groups

  input = each.key

  lifecycle {
    precondition {
      condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9_.-]*$", each.key))
      error_message = "Rule-group key '${each.key}' is invalid. Use letters, numbers, '.', '_', or '-' and do not include '/'."
    }

    precondition {
      condition = (
        each.value.create
        ? each.value.arn == null && each.value.metadata == null
        : each.value.arn != null && trimspace(each.value.arn) != "" && each.value.metadata != null
      )
      error_message = "Rule group '${each.key}' must choose create mode (no arn/metadata) or inject mode (create=false plus arn and metadata {type, rule_order, declared_capacity, kind})."
    }

    precondition {
      condition     = contains(["terraform", "external"], each.value.content_management)
      error_message = "Rule group '${each.key}' content_management must be terraform or external."
    }

    precondition {
      condition     = each.value.create || each.value.content_management == "terraform"
      error_message = "Injected rule group '${each.key}' cannot declare content_management; ownership belongs to the ARN provider."
    }

    precondition {
      condition = !each.value.create || (
        each.value.name != null && trimspace(each.value.name) != "" &&
        each.value.type != null && contains(["STATEFUL", "STATELESS"], each.value.type) &&
        each.value.capacity != null && each.value.capacity >= 1 && each.value.capacity <= 30000 && floor(each.value.capacity) == each.value.capacity
      )
      error_message = "Created rule group '${each.key}' requires name, type STATEFUL|STATELESS, and integer capacity 1..30000. Name, type, capacity, and rule_order are replacement identity."
    }

    precondition {
      condition     = !each.value.create || length(local.source_lanes[each.key]) == 1
      error_message = "Created rule group '${each.key}' must set exactly one source lane: rules_string, rules_source_list, stateful_rules, or stateless_rules."
    }

    precondition {
      condition = !each.value.create || (
        (contains(["rules_string", "rules_source_list", "stateful_rules"], try(local.source_lanes[each.key][0], "")) && each.value.type == "STATEFUL") ||
        (try(local.source_lanes[each.key][0], "") == "stateless_rules" && each.value.type == "STATELESS")
      )
      error_message = "Rule group '${each.key}' source lane is incompatible with its type. Stateless rules require STATELESS; all other lanes require STATEFUL."
    }

    precondition {
      condition     = !each.value.create || each.value.type == "STATELESS" || each.value.rule_order == "STRICT_ORDER"
      error_message = "Stateful rule group '${each.key}' must use STRICT_ORDER; ActionOrder adoption is not supported."
    }

    precondition {
      condition     = length(local.missing_ip_sets[each.key]) == 0
      error_message = "Rule group '${each.key}' has missing or empty required_ip_sets: ${join(", ", sort(tolist(local.missing_ip_sets[each.key])))}. Bind every declared Suricata IP variable."
    }

    precondition {
      condition     = length(local.missing_port_sets[each.key]) == 0
      error_message = "Rule group '${each.key}' has missing or empty required_port_sets: ${join(", ", sort(tolist(local.missing_port_sets[each.key])))}. Bind every declared Suricata port variable."
    }

    precondition {
      condition     = length(local.sid_values[each.key]) == length(distinct(local.sid_values[each.key]))
      error_message = "Rule group '${each.key}' contains duplicate Suricata sid values. Every sid must be unique within the group."
    }

    precondition {
      condition = each.value.sid_range == null || (
        each.value.sid_range.min <= each.value.sid_range.max &&
        alltrue([for sid in local.sid_values[each.key] : sid >= each.value.sid_range.min && sid <= each.value.sid_range.max])
      )
      error_message = "Rule group '${each.key}' has a Suricata sid outside its declared sid_range ${try(each.value.sid_range.min, 0)}..${try(each.value.sid_range.max, 0)}."
    }

    precondition {
      condition = !each.value.create || each.value.content_management == "external" || (
        each.value.source_validation != null && contains(["attested", "aws_apply"], each.value.source_validation.mode)
      )
      error_message = "Terraform-managed rule group '${each.key}' requires source_validation.mode attested or aws_apply."
    }

    precondition {
      condition     = !each.value.create || each.value.content_management != "external" || each.value.source_validation == null
      error_message = "Externally managed rule group '${each.key}' cannot set source_validation: the seed is bootstrap only and live content belongs to the external UpdateRuleGroup pipeline."
    }

    precondition {
      condition = try(each.value.source_validation.mode, null) != "attested" || (
        try(trimspace(each.value.source_validation.manifest_uri), "") != "" &&
        can(regex("^[0-9a-fA-F]{64}$", try(each.value.source_validation.bundle_sha256, "")))
      )
      error_message = "Attested rule group '${each.key}' requires an external manifest_uri and a 64-character bundle_sha256; do not self-attest with filesha256 of the same source file."
    }

    precondition {
      condition = try(each.value.source.rules_source_list, null) == null || (
        contains(["ALLOWLIST", "DENYLIST"], each.value.source.rules_source_list.generated_rules_type) &&
        length(each.value.source.rules_source_list.targets) > 0 &&
        length(each.value.source.rules_source_list.target_types) > 0 &&
        alltrue([for target_type in each.value.source.rules_source_list.target_types : contains(["HTTP_HOST", "TLS_SNI"], target_type)])
      )
      error_message = "Domain-list rule group '${each.key}' requires ALLOWLIST|DENYLIST, non-empty targets, and target_types HTTP_HOST|TLS_SNI."
    }

    precondition {
      condition = try(each.value.source.stateless_rules, null) == null || (
        alltrue([for rule in values(each.value.source.stateless_rules) : rule.priority >= 1 && rule.priority <= 65535 && floor(rule.priority) == rule.priority]) &&
        length(distinct([for rule in values(each.value.source.stateless_rules) : rule.priority])) == length(each.value.source.stateless_rules)
      )
      error_message = "Stateless rule group '${each.key}' requires unique integer priorities from 1 through 65535."
    }

    precondition {
      condition = (
        each.value.encryption.type == "AWS_OWNED_KMS_KEY" && each.value.encryption.key_arn == null
        ) || (
        each.value.encryption.type == "CUSTOMER_KMS" && try(trimspace(each.value.encryption.key_arn), "") != ""
      )
      error_message = "Rule group '${each.key}' encryption must use AWS_OWNED_KMS_KEY without key_arn or CUSTOMER_KMS with key_arn."
    }

    precondition {
      condition = each.value.create || try(
        contains(["STATEFUL", "STATELESS"], each.value.metadata.type) &&
        (each.value.metadata.type == "STATELESS" || each.value.metadata.rule_order == "STRICT_ORDER") &&
        each.value.metadata.declared_capacity >= 1 && each.value.metadata.declared_capacity <= 30000 &&
        contains(["managed", "customer"], each.value.metadata.kind),
        false,
      )
      error_message = "Injected rule group '${each.key}' metadata must attest type, STRICT_ORDER compatibility, declared_capacity 1..30000, and kind managed|customer; remote verification is unavailable."
    }
  }
}

resource "aws_networkfirewall_rule_group" "terraform_content" {
  for_each = local.terraform_content_groups

  name        = each.value.name
  description = each.value.description
  type        = each.value.type
  capacity    = each.value.capacity
  tags        = each.value.tags

  dynamic "encryption_configuration" {
    for_each = each.value.encryption.type == "CUSTOMER_KMS" ? [each.value.encryption] : []
    content {
      type   = "CUSTOMER_KMS"
      key_id = encryption_configuration.value.key_arn
    }
  }

  rule_group {
    dynamic "stateful_rule_options" {
      for_each = each.value.type == "STATEFUL" ? [each.value.rule_order] : []
      content { rule_order = stateful_rule_options.value }
    }

    dynamic "rule_variables" {
      for_each = length(each.value.ip_sets) + length(each.value.port_sets) > 0 ? [1] : []
      content {
        dynamic "ip_sets" {
          for_each = each.value.ip_sets
          content {
            key = ip_sets.key
            ip_set { definition = ip_sets.value }
          }
        }
        dynamic "port_sets" {
          for_each = each.value.port_sets
          content {
            key = port_sets.key
            port_set { definition = port_sets.value }
          }
        }
      }
    }

    rules_source {
      rules_string = try(each.value.source.rules_string, null)

      dynamic "rules_source_list" {
        for_each = try(each.value.source.rules_source_list, null) == null ? [] : [each.value.source.rules_source_list]
        content {
          generated_rules_type = rules_source_list.value.generated_rules_type
          target_types         = rules_source_list.value.target_types
          targets              = rules_source_list.value.targets
        }
      }

      dynamic "stateful_rule" {
        for_each = coalesce(try(each.value.source.stateful_rules, null), {})
        content {
          action = stateful_rule.value.action
          header {
            protocol         = stateful_rule.value.header.protocol
            source           = stateful_rule.value.header.source
            source_port      = stateful_rule.value.header.source_port
            direction        = stateful_rule.value.header.direction
            destination      = stateful_rule.value.header.destination
            destination_port = stateful_rule.value.header.destination_port
          }
          dynamic "rule_option" {
            for_each = stateful_rule.value.options
            content {
              keyword  = rule_option.value.keyword
              settings = rule_option.value.settings
            }
          }
        }
      }

      dynamic "stateless_rules_and_custom_actions" {
        for_each = try(each.value.source.stateless_rules, null) == null ? [] : [each.value.source.stateless_rules]
        content {
          dynamic "stateless_rule" {
            for_each = stateless_rules_and_custom_actions.value
            content {
              priority = stateless_rule.value.priority
              rule_definition {
                actions = stateless_rule.value.actions
                match_attributes {
                  protocols = stateless_rule.value.match.protocols
                  dynamic "source" {
                    for_each = stateless_rule.value.match.sources
                    content { address_definition = source.value }
                  }
                  dynamic "destination" {
                    for_each = stateless_rule.value.match.destinations
                    content { address_definition = destination.value }
                  }
                  dynamic "source_port" {
                    for_each = stateless_rule.value.match.source_ports
                    content {
                      from_port = source_port.value.from
                      to_port   = source_port.value.to
                    }
                  }
                  dynamic "destination_port" {
                    for_each = stateless_rule.value.match.destination_ports
                    content {
                      from_port = destination_port.value.from
                      to_port   = destination_port.value.to
                    }
                  }
                  dynamic "tcp_flag" {
                    for_each = stateless_rule.value.match.tcp_flags
                    content {
                      flags = tcp_flag.value.flags
                      masks = tcp_flag.value.masks
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  depends_on = [terraform_data.rule_group_contract]
}

resource "aws_networkfirewall_rule_group" "external_content" {
  for_each = local.external_content_groups

  name        = each.value.name
  description = each.value.description
  type        = each.value.type
  capacity    = each.value.capacity
  tags        = each.value.tags

  dynamic "encryption_configuration" {
    for_each = each.value.encryption.type == "CUSTOMER_KMS" ? [each.value.encryption] : []
    content {
      type   = "CUSTOMER_KMS"
      key_id = encryption_configuration.value.key_arn
    }
  }

  rule_group {
    dynamic "stateful_rule_options" {
      for_each = each.value.type == "STATEFUL" ? [each.value.rule_order] : []
      content { rule_order = stateful_rule_options.value }
    }
    dynamic "rule_variables" {
      for_each = length(each.value.ip_sets) + length(each.value.port_sets) > 0 ? [1] : []
      content {
        dynamic "ip_sets" {
          for_each = each.value.ip_sets
          content {
            key = ip_sets.key
            ip_set { definition = ip_sets.value }
          }
        }
        dynamic "port_sets" {
          for_each = each.value.port_sets
          content {
            key = port_sets.key
            port_set { definition = port_sets.value }
          }
        }
      }
    }
    rules_source {
      rules_string = try(each.value.source.rules_string, null)
      dynamic "rules_source_list" {
        for_each = try(each.value.source.rules_source_list, null) == null ? [] : [each.value.source.rules_source_list]
        content {
          generated_rules_type = rules_source_list.value.generated_rules_type
          target_types         = rules_source_list.value.target_types
          targets              = rules_source_list.value.targets
        }
      }
      dynamic "stateful_rule" {
        for_each = coalesce(try(each.value.source.stateful_rules, null), {})
        content {
          action = stateful_rule.value.action
          header {
            protocol         = stateful_rule.value.header.protocol
            source           = stateful_rule.value.header.source
            source_port      = stateful_rule.value.header.source_port
            direction        = stateful_rule.value.header.direction
            destination      = stateful_rule.value.header.destination
            destination_port = stateful_rule.value.header.destination_port
          }
          dynamic "rule_option" {
            for_each = stateful_rule.value.options
            content {
              keyword  = rule_option.value.keyword
              settings = rule_option.value.settings
            }
          }
        }
      }
      dynamic "stateless_rules_and_custom_actions" {
        for_each = try(each.value.source.stateless_rules, null) == null ? [] : [each.value.source.stateless_rules]
        content {
          dynamic "stateless_rule" {
            for_each = stateless_rules_and_custom_actions.value
            content {
              priority = stateless_rule.value.priority
              rule_definition {
                actions = stateless_rule.value.actions
                match_attributes {
                  protocols = stateless_rule.value.match.protocols
                  dynamic "source" {
                    for_each = stateless_rule.value.match.sources
                    content { address_definition = source.value }
                  }
                  dynamic "destination" {
                    for_each = stateless_rule.value.match.destinations
                    content { address_definition = destination.value }
                  }
                  dynamic "source_port" {
                    for_each = stateless_rule.value.match.source_ports
                    content {
                      from_port = source_port.value.from
                      to_port   = source_port.value.to
                    }
                  }
                  dynamic "destination_port" {
                    for_each = stateless_rule.value.match.destination_ports
                    content {
                      from_port = destination_port.value.from
                      to_port   = destination_port.value.to
                    }
                  }
                  dynamic "tcp_flag" {
                    for_each = stateless_rule.value.match.tcp_flags
                    content {
                      flags = tcp_flag.value.flags
                      masks = tcp_flag.value.masks
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [rule_group, rules]
  }

  depends_on = [terraform_data.rule_group_contract]
}

locals {
  created_rule_group_arns = merge(
    { for key, group in aws_networkfirewall_rule_group.terraform_content : key => group.arn },
    { for key, group in aws_networkfirewall_rule_group.external_content : key => group.arn },
  )
  rule_group_arns = {
    for key, group in var.rule_groups : key => group.create ? local.created_rule_group_arns[key] : group.arn
  }
  rule_group_records = {
    for key, group in var.rule_groups : key => {
      arn                = local.rule_group_arns[key]
      type               = group.create ? group.type : try(group.metadata.type, null)
      rule_order         = group.create ? group.rule_order : try(group.metadata.rule_order, null)
      declared_capacity  = group.create ? group.capacity : try(group.metadata.declared_capacity, null)
      kind               = group.create ? "customer" : try(group.metadata.kind, null)
      content_management = group.create ? group.content_management : "injected"
      requires_home_net  = group.requires_home_net || try(group.source.rules_source_list.generated_rules_type, null) == "ALLOWLIST"
      validation_mode    = group.create && group.content_management == "terraform" ? group.source_validation.mode : "unverified"
    }
  }
}
