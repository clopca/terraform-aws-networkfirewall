locals {
  created_firewalls = {
    for key, firewall in var.firewalls : key => firewall if firewall.create
  }

  injected_firewalls = {
    for key, firewall in var.firewalls : key => firewall if !firewall.create
  }

  endpoint_records_by_created_firewall = {
    for firewall_key, firewall in local.created_firewalls : firewall_key => {
      for zone_key, endpoint in firewall.placement.vpc.endpoint_subnets : zone_key => {
        endpoint_id = try([
          for sync_state in aws_networkfirewall_firewall.this[firewall_key].firewall_status[0].sync_states :
          sync_state.attachment[0].endpoint_id
          if sync_state.attachment[0].subnet_id == endpoint.subnet_id
        ][0], null)
        subnet_id = endpoint.subnet_id
        status    = null
      }
    }
  }

  endpoint_records_by_firewall = {
    for firewall_key, firewall in var.firewalls : firewall_key => (
      firewall.create ? local.endpoint_records_by_created_firewall[firewall_key] : {}
    )
  }
}

resource "terraform_data" "firewall_contract" {
  for_each = var.firewalls

  input = each.key

  lifecycle {
    precondition {
      condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9_.-]*$", each.key))
      error_message = "Firewall key '${each.key}' is invalid. Use letters, numbers, '.', '_', or '-' and do not include '/'."
    }

    precondition {
      condition = each.value.create ? (
        each.value.arn == null &&
        each.value.name != null && trimspace(each.value.name) != "" &&
        each.value.policy_arn != null && trimspace(each.value.policy_arn) != ""
        ) : (
        each.value.arn != null && trimspace(each.value.arn) != ""
      )
      error_message = "Firewall '${each.key}' must choose exactly one lifecycle mode: create=true requires name and policy_arn and forbids arn; create=false requires arn."
    }

    precondition {
      condition = each.value.create || (
        each.value.name == null &&
        each.value.description == null &&
        each.value.policy_arn == null &&
        each.value.placement == null
      )
      error_message = "Injected firewall '${each.key}' cannot include managed name, description, policy_arn, or placement. Remove them and supply only create=false plus arn."
    }

    precondition {
      condition = !each.value.create || (
        each.value.placement != null &&
        each.value.placement.vpc != null &&
        each.value.placement.transit_gateway == null
      )
      error_message = "Firewall '${each.key}' must configure exactly one placement. Use placement.vpc; placement.transit_gateway is reserved and not yet implemented."
    }

    precondition {
      condition     = try(each.value.placement.transit_gateway, null) == null
      error_message = "Firewall '${each.key}' uses placement.transit_gateway, which is reserved and not yet implemented. Use placement.vpc in v2.0."
    }

    precondition {
      condition     = !each.value.create || try(length(each.value.placement.vpc.endpoint_subnets) > 0, false)
      error_message = "Firewall '${each.key}' must define at least one placement.vpc.endpoint_subnets entry. Add one caller-keyed subnet per endpoint zone."
    }

    precondition {
      condition = !each.value.create || try(alltrue([
        for zone_key in keys(each.value.placement.vpc.endpoint_subnets) :
        can(regex("^[A-Za-z0-9][A-Za-z0-9_.-]*$", zone_key))
      ]), false)
      error_message = "Firewall '${each.key}' has an invalid endpoint_subnets key. Use letters, numbers, '.', '_', or '-' and do not include '/'."
    }

    precondition {
      condition = !each.value.create || try(
        length(distinct([for endpoint in values(each.value.placement.vpc.endpoint_subnets) : endpoint.subnet_id])) ==
        length(each.value.placement.vpc.endpoint_subnets),
        false,
      )
      error_message = "Firewall '${each.key}' assigns the same subnet_id to multiple zone keys. Use one unique subnet per endpoint zone."
    }

    precondition {
      condition = !each.value.create || try(alltrue([
        for endpoint in values(each.value.placement.vpc.endpoint_subnets) :
        contains(["IPV4", "IPV6", "DUALSTACK"], endpoint.ip_address_type)
      ]), false)
      error_message = "Firewall '${each.key}' has an invalid ip_address_type. Use IPV4, IPV6, or DUALSTACK."
    }

    precondition {
      condition = (
        each.value.encryption.type == "CUSTOMER_KMS" && each.value.encryption.key_arn != null && trimspace(each.value.encryption.key_arn) != ""
        ) || (
        each.value.encryption.type == "AWS_OWNED_KMS_KEY" && each.value.encryption.key_arn == null
      )
      error_message = "Firewall '${each.key}' encryption must be AWS_OWNED_KMS_KEY without key_arn or CUSTOMER_KMS with key_arn."
    }
  }
}
