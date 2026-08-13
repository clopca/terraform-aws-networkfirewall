locals {
  mode_level = {
    observation = 0
    selective   = 1
    enforce     = 2
  }
  blocking_actions = toset(["drop", "reject"])

  rule_group_records_by_arn = {
    for record_key, record in var.rule_group_records : record.arn => merge(record, { record_key = record_key })
  }

  effective_requires_home_net = {
    for policy_key, policy in var.policies : policy_key => {
      for group_key, reference in policy.stateful_rule_groups : group_key => coalesce(
        reference.requires_home_net,
        try(local.rule_group_records_by_arn[reference.arn].requires_home_net, null),
        false,
      )
    }
  }

  stateful_duplicate_priorities = {
    for policy_key, policy in var.policies : policy_key => {
      for priority in distinct([for reference in values(policy.stateful_rule_groups) : reference.priority]) :
      tostring(priority) => sort([
        for group_key, reference in policy.stateful_rule_groups : group_key if reference.priority == priority
      ])
      if length([for reference in values(policy.stateful_rule_groups) : reference if reference.priority == priority]) > 1
    }
  }

  stateless_duplicate_priorities = {
    for policy_key, policy in var.policies : policy_key => {
      for priority in distinct([for reference in values(policy.stateless_rule_groups) : reference.priority]) :
      tostring(priority) => sort([
        for group_key, reference in policy.stateless_rule_groups : group_key if reference.priority == priority
      ])
      if length([for reference in values(policy.stateless_rule_groups) : reference if reference.priority == priority]) > 1
    }
  }

  stateful_decisions = {
    for policy_key, policy in var.policies : policy_key => {
      for group_key, reference in policy.stateful_rule_groups : group_key => {
        blocking  = length(setintersection(reference.behavior.actions, local.blocking_actions)) > 0
        directive = lookup(policy.incident_control.group_overrides, group_key, null)
        observe = (
          lookup(policy.incident_control.group_overrides, group_key, null) == "observe" ||
          (
            lookup(policy.incident_control.group_overrides, group_key, null) != "force_enforce" &&
            (
              policy.incident_control.mode == "observe_all_stateful" ||
              local.mode_level[policy.enforcement.mode] < local.mode_level[reference.enforce_from]
            )
          )
        )
      }
    }
  }

  stateful_default_actions = {
    for key, policy in var.policies : key => (
      policy.incident_control.mode == "observe_all_stateful" || policy.enforcement.mode != "enforce"
      ? toset(["aws:alert_strict"])
      : toset(["aws:drop_strict", "aws:alert_strict"])
    )
  }
}

resource "terraform_data" "policy_contract" {
  for_each = var.policies

  input = each.key

  lifecycle {
    precondition {
      condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9_.-]*-(plain|tls)$", each.key))
      error_message = "Policy key '${each.key}' must be an immutable release key ending in -plain or -tls."
    }

    precondition {
      condition = (
        each.value.create
        ? each.value.arn == null && each.value.metadata == null && each.value.name != null && trimspace(each.value.name) != ""
        : each.value.arn != null && trimspace(each.value.arn) != "" && each.value.metadata != null
      )
      error_message = "Policy release '${each.key}' must choose create mode (name, no arn/metadata) or inject mode (create=false plus arn and metadata)."
    }

    precondition {
      condition     = !each.value.create || strcontains(each.value.name, each.key)
      error_message = "Policy release '${each.key}' physical name must contain the release key so candidate/active/LKG identity remains explicit."
    }

    precondition {
      condition = (
        endswith(each.key, "-tls") && each.value.tls != null
        ) || (
        endswith(each.key, "-plain") && each.value.tls == null
      )
      error_message = "Policy release '${each.key}' TLS presence must match its -tls or -plain suffix; adding/removing TLS requires a new release key."
    }

    precondition {
      condition     = each.value.create || (each.value.metadata.rule_order == "STRICT_ORDER" && each.value.metadata.tls_enabled == (each.value.tls != null))
      error_message = "Injected policy '${each.key}' metadata must attest STRICT_ORDER and TLS presence matching the release suffix. ActionOrder adoption is unsupported."
    }

    precondition {
      condition     = contains(["observation", "selective", "enforce"], each.value.enforcement.mode)
      error_message = "Policy release '${each.key}' enforcement.mode must be observation, selective, or enforce."
    }

    precondition {
      condition     = contains(["normal", "observe_all_stateful"], each.value.incident_control.mode)
      error_message = "Policy release '${each.key}' incident_control.mode must be normal or observe_all_stateful."
    }

    precondition {
      condition = alltrue([
        for group_key, directive in each.value.incident_control.group_overrides :
        contains(keys(each.value.stateful_rule_groups), group_key) && contains(["observe", "force_enforce"], directive)
      ])
      error_message = "Policy release '${each.key}' incident group_overrides must name existing stateful slots and use observe or force_enforce."
    }

    precondition {
      condition = (
        each.value.incident_control.mode == "normal" && length(each.value.incident_control.group_overrides) == 0
        ) || (
        try(trimspace(each.value.incident_control.change_id), "") != "" &&
        try(trimspace(each.value.incident_control.owner), "") != "" &&
        can(regex("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$", try(each.value.incident_control.expires_at, "")))
      )
      error_message = "Policy release '${each.key}' non-normal incident posture requires change_id, owner, and RFC3339 UTC expires_at metadata; Terraform does not auto-expire it."
    }

    precondition {
      condition     = length(each.value.stateful_rule_groups) <= 20
      error_message = "Policy release '${each.key}' exceeds the AWS quota of 20 stateful rule-group references."
    }

    precondition {
      condition     = length(each.value.stateless_rule_groups) <= 20
      error_message = "Policy release '${each.key}' exceeds the AWS quota of 20 stateless rule-group references."
    }

    precondition {
      condition = alltrue([
        for reference in values(each.value.stateful_rule_groups) :
        reference.priority >= 1 && reference.priority <= 65535 && floor(reference.priority) == reference.priority
      ]) && length(distinct([for reference in values(each.value.stateful_rule_groups) : reference.priority])) == length(each.value.stateful_rule_groups)
      error_message = "Policy release '${each.key}' stateful priorities must be unique integers from 1 through 65535. Duplicates: ${join("; ", [for priority, group_keys in local.stateful_duplicate_priorities[each.key] : "${priority} => [${join(", ", group_keys)}]"])}."
    }

    precondition {
      condition = alltrue([
        for reference in values(each.value.stateless_rule_groups) :
        reference.priority >= 1 && reference.priority <= 65535 && floor(reference.priority) == reference.priority
      ]) && length(distinct([for reference in values(each.value.stateless_rule_groups) : reference.priority])) == length(each.value.stateless_rule_groups)
      error_message = "Policy release '${each.key}' stateless priorities must be unique integers from 1 through 65535. Duplicates: ${join("; ", [for priority, group_keys in local.stateless_duplicate_priorities[each.key] : "${priority} => [${join(", ", group_keys)}]"])}."
    }

    precondition {
      condition = alltrue([
        for reference in values(each.value.stateful_rule_groups) :
        contains(["managed", "customer"], reference.kind) &&
        reference.rule_order == "STRICT_ORDER" &&
        reference.declared_capacity >= 1 && reference.declared_capacity <= 30000 &&
        contains(["observation", "selective", "enforce"], reference.enforce_from)
      ])
      error_message = "Policy release '${each.key}' stateful slots must attest kind managed|customer, STRICT_ORDER, capacity 1..30000, and a valid enforce_from level."
    }

    precondition {
      condition = alltrue([
        for reference in values(each.value.stateless_rule_groups) :
        reference.always_enforced && reference.declared_capacity >= 1 && reference.declared_capacity <= 30000
      ])
      error_message = "Policy release '${each.key}' stateless slots require always_enforced=true and declared_capacity 1..30000; stateless drops have no observation mode."
    }

    precondition {
      condition     = sum(concat([0], [for reference in values(each.value.stateful_rule_groups) : reference.declared_capacity])) <= 30000
      error_message = "Policy release '${each.key}' exceeds 30000 total declared stateful capacity units."
    }

    precondition {
      condition     = sum(concat([0], [for reference in values(each.value.stateless_rule_groups) : reference.declared_capacity])) <= 30000
      error_message = "Policy release '${each.key}' exceeds 30000 total declared stateless capacity units."
    }

    precondition {
      condition = alltrue([
        for reference in values(each.value.stateful_rule_groups) :
        !contains(keys(local.rule_group_records_by_arn), reference.arn) || (
          local.rule_group_records_by_arn[reference.arn].type == "STATEFUL" &&
          reference.kind == local.rule_group_records_by_arn[reference.arn].kind &&
          reference.rule_order == local.rule_group_records_by_arn[reference.arn].rule_order &&
          reference.declared_capacity == local.rule_group_records_by_arn[reference.arn].declared_capacity &&
          (reference.requires_home_net == null || reference.requires_home_net == local.rule_group_records_by_arn[reference.arn].requires_home_net)
        )
      ])
      error_message = "Policy release '${each.key}' has a stateful reference inconsistent with matching rule_group_records metadata (type, kind, rule_order, declared_capacity, or explicitly declared requires_home_net)."
    }

    precondition {
      condition = alltrue([
        for reference in values(each.value.stateful_rule_groups) :
        length(reference.behavior.actions) > 0 &&
        length(setsubtract(reference.behavior.actions, toset(["alert", "drop", "reject", "pass"]))) == 0 &&
        contains(["all_blocking", "drop_only", "none"], reference.behavior.override_coverage) &&
        reference.behavior.has_terminal_action == contains(reference.behavior.actions, "pass")
      ])
      error_message = "Policy release '${each.key}' behavior must use actions alert|drop|reject|pass, consistent has_terminal_action, and override_coverage all_blocking|drop_only|none."
    }

    precondition {
      condition = alltrue([
        for group_key, reference in each.value.stateful_rule_groups :
        !local.stateful_decisions[each.key][group_key].observe ||
        !local.stateful_decisions[each.key][group_key].blocking ||
        reference.behavior.override_coverage == "all_blocking"
      ])
      error_message = "Policy release '${each.key}' cannot observe a blocking group unless behavior.override_coverage is all_blocking. Supply complete alert-only coverage or force enforcement."
    }

    precondition {
      condition = alltrue([
        for group_key, reference in each.value.stateful_rule_groups :
        reference.kind != "customer" ||
        !local.stateful_decisions[each.key][group_key].observe ||
        !local.stateful_decisions[each.key][group_key].blocking ||
        try(trimspace(reference.observation_arn), "") != ""
      ])
      error_message = "Policy release '${each.key}' would observe a blocking customer group without observation_arn. Supply an independently validated alert-only observation_arn, raise enforcement.mode to the slot threshold, lower enforce_from deliberately, or use an incident force_enforce override. DROP_TO_ALERT is managed-only."
    }

    precondition {
      condition = !anytrue([
        for group_key, reference in each.value.stateful_rule_groups : local.effective_requires_home_net[each.key][group_key]
        ]) || (
        each.value.home_net_cidrs != null && length(each.value.home_net_cidrs) > 0
      )
      error_message = "Policy release '${each.key}' has references requiring HOME_NET. Set non-empty home_net_cidrs; this is the only policy-variable source and is required for generated ALLOWLIST groups."
    }

    precondition {
      condition     = contains(["DROP", "CONTINUE", "REJECT"], each.value.stream_exception_policy)
      error_message = "Policy release '${each.key}' stream_exception_policy must be DROP, CONTINUE, or REJECT. Changing it can restart the stateful engine."
    }

    precondition {
      condition     = each.value.tcp_idle_timeout_seconds >= 60 && each.value.tcp_idle_timeout_seconds <= 6000 && floor(each.value.tcp_idle_timeout_seconds) == each.value.tcp_idle_timeout_seconds
      error_message = "Policy release '${each.key}' tcp_idle_timeout_seconds must be an integer from 60 through 6000. Changing it can restart the stateful engine."
    }

    precondition {
      condition = (
        each.value.encryption.type == "AWS_OWNED_KMS_KEY" && each.value.encryption.key_arn == null
        ) || (
        each.value.encryption.type == "CUSTOMER_KMS" && try(trimspace(each.value.encryption.key_arn), "") != ""
      )
      error_message = "Policy release '${each.key}' encryption must use AWS_OWNED_KMS_KEY without key_arn or CUSTOMER_KMS with key_arn."
    }
  }
}

resource "aws_networkfirewall_firewall_policy" "this" {
  for_each = { for key, policy in var.policies : key => policy if policy.create }

  name        = each.value.name
  description = each.value.description
  tags        = each.value.tags

  dynamic "encryption_configuration" {
    for_each = each.value.encryption.type == "CUSTOMER_KMS" ? [each.value.encryption] : []
    content {
      type   = "CUSTOMER_KMS"
      key_id = encryption_configuration.value.key_arn
    }
  }

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]
    stateful_default_actions           = local.stateful_default_actions[each.key]

    tls_inspection_configuration_arn = try(each.value.tls.inspection_configuration_arn, null)
    enable_tls_session_holding       = try(each.value.tls.enable_session_holding, null)

    stateful_engine_options {
      rule_order              = "STRICT_ORDER"
      stream_exception_policy = each.value.stream_exception_policy
      flow_timeouts {
        tcp_idle_timeout_seconds = each.value.tcp_idle_timeout_seconds
      }
    }

    dynamic "policy_variables" {
      for_each = each.value.home_net_cidrs == null ? [] : [each.value.home_net_cidrs]
      content {
        rule_variables {
          key = "HOME_NET"
          ip_set { definition = policy_variables.value }
        }
      }
    }

    dynamic "stateful_rule_group_reference" {
      for_each = each.value.stateful_rule_groups
      content {
        resource_arn = (
          local.stateful_decisions[each.key][stateful_rule_group_reference.key].observe &&
          local.stateful_decisions[each.key][stateful_rule_group_reference.key].blocking &&
          stateful_rule_group_reference.value.kind == "customer"
          ? stateful_rule_group_reference.value.observation_arn
          : stateful_rule_group_reference.value.arn
        )
        priority               = stateful_rule_group_reference.value.priority
        deep_threat_inspection = stateful_rule_group_reference.value.deep_threat_inspection

        dynamic "override" {
          for_each = (
            local.stateful_decisions[each.key][stateful_rule_group_reference.key].observe &&
            local.stateful_decisions[each.key][stateful_rule_group_reference.key].blocking &&
            stateful_rule_group_reference.value.kind == "managed"
          ) ? ["DROP_TO_ALERT"] : []
          content { action = override.value }
        }
      }
    }

    dynamic "stateless_rule_group_reference" {
      for_each = each.value.stateless_rule_groups
      content {
        resource_arn = stateless_rule_group_reference.value.arn
        priority     = stateless_rule_group_reference.value.priority
      }
    }
  }

  depends_on = [terraform_data.policy_contract]
}

locals {
  policy_arns = {
    for key, policy in var.policies : key => policy.create ? aws_networkfirewall_firewall_policy.this[key].arn : policy.arn
  }

  effective_releases = {
    for policy_key, policy in var.policies : policy_key => {
      arn                      = local.policy_arns[policy_key]
      release                  = policy_key
      rule_order               = "STRICT_ORDER"
      tls_enabled              = policy.tls != null
      enforcement_mode         = policy.enforcement.mode
      incident_mode            = policy.incident_control.mode
      stateful_default_actions = local.stateful_default_actions[policy_key]
      stateful_rule_groups = {
        for group_key, reference in policy.stateful_rule_groups : group_key => {
          arn = (
            local.stateful_decisions[policy_key][group_key].observe &&
            local.stateful_decisions[policy_key][group_key].blocking &&
            reference.kind == "customer"
            ? reference.observation_arn
            : reference.arn
          )
          priority          = reference.priority
          kind              = reference.kind
          observed          = local.stateful_decisions[policy_key][group_key].observe
          override_action   = local.stateful_decisions[policy_key][group_key].observe && local.stateful_decisions[policy_key][group_key].blocking && reference.kind == "managed" ? "DROP_TO_ALERT" : null
          behavior          = reference.behavior
          declared_capacity = reference.declared_capacity
          requires_home_net = local.effective_requires_home_net[policy_key][group_key]
        }
      }
      stateless_rule_groups = policy.stateless_rule_groups
      incident_metadata = {
        change_id  = policy.incident_control.change_id
        owner      = policy.incident_control.owner
        expires_at = policy.incident_control.expires_at
      }
    }
  }
}
