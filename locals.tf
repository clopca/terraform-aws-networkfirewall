locals {
  created_firewalls = {
    for key, firewall in var.firewalls : key => firewall if firewall.create
  }

  injected_firewalls = {
    for key, firewall in var.firewalls : key => firewall if !firewall.create
  }

  created_vpc_endpoint_records = {
    for firewall_key, firewall in local.created_firewalls : firewall_key => {
      for availability_zone, endpoint in firewall.placement.vpc.endpoint_subnets : availability_zone => {
        vpc_endpoint_id = try([
          for sync_state in aws_networkfirewall_firewall.this[firewall_key].firewall_status[0].sync_states :
          sync_state.attachment[0].endpoint_id
          if sync_state.attachment[0].subnet_id == endpoint.subnet_id
        ][0], null)
        subnet_id            = endpoint.subnet_id
        availability_zone    = availability_zone
        availability_zone_id = endpoint.availability_zone_id
        ip_address_type      = endpoint.ip_address_type
        readiness_guarantee  = "provider_waited"
      }
    }
  }

  injected_vpc_endpoint_records = {
    for firewall_key, firewall in local.injected_firewalls : firewall_key => (
      try(firewall.placement.vpc, null) == null ? {} : {
        for availability_zone, endpoint in firewall.placement.vpc.endpoint_subnets : availability_zone => {
          vpc_endpoint_id = try([
            for sync_state in data.aws_networkfirewall_firewall.this[firewall_key].firewall_status[0].sync_states :
            sync_state.attachment[0].endpoint_id
            if sync_state.availability_zone == availability_zone && sync_state.attachment[0].subnet_id == endpoint.subnet_id
          ][0], null)
          subnet_id            = endpoint.subnet_id
          availability_zone    = availability_zone
          availability_zone_id = endpoint.availability_zone_id
          ip_address_type      = endpoint.ip_address_type
          readiness_guarantee = try([
            for sync_state in data.aws_networkfirewall_firewall.this[firewall_key].firewall_status[0].sync_states :
            sync_state.attachment[0].status == "READY" ? "observed_ready" : "unverified"
            if sync_state.availability_zone == availability_zone && sync_state.attachment[0].subnet_id == endpoint.subnet_id
          ][0], "unverified")
        }
      }
    )
  }

  vpc_endpoint_records_by_firewall = merge(
    local.created_vpc_endpoint_records,
    local.injected_vpc_endpoint_records,
  )
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
        each.value.policy_arn == null
      )
      error_message = "Injected firewall '${each.key}' cannot include managed name, description, or policy_arn. Remove them; placement.vpc, when present, is observation metadata only."
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
      condition = try(each.value.placement.vpc, null) == null || try(
        length(each.value.placement.vpc.endpoint_subnets) > 0,
        false,
      )
      error_message = "Firewall '${each.key}' placement.vpc must define at least one endpoint_subnets entry, with at most one subnet under each Availability Zone name."
    }

    precondition {
      condition = try(each.value.placement.vpc, null) == null || try(alltrue([
        for availability_zone in keys(each.value.placement.vpc.endpoint_subnets) :
        can(regex("^[a-z]{2}(?:-[a-z]+)+-[0-9][a-z]$", availability_zone))
      ]), false)
      error_message = "Firewall '${each.key}' has an invalid endpoint_subnets key. Keys must be AWS Availability Zone names such as us-east-1a; one map key permits at most one subnet per AZ."
    }

    precondition {
      condition = try(each.value.placement.vpc, null) == null || try(
        length(distinct([for endpoint in values(each.value.placement.vpc.endpoint_subnets) : endpoint.subnet_id])) ==
        length(each.value.placement.vpc.endpoint_subnets),
        false,
      )
      error_message = "Firewall '${each.key}' assigns the same subnet_id to multiple Availability Zones. Use one unique subnet per AZ."
    }

    precondition {
      condition = try(each.value.placement.vpc, null) == null || try(alltrue([
        for endpoint in values(each.value.placement.vpc.endpoint_subnets) :
        contains(["IPV4", "IPV6", "DUALSTACK"], endpoint.ip_address_type)
      ]), false)
      error_message = "Firewall '${each.key}' has an invalid ip_address_type. Use IPV4, IPV6, or DUALSTACK. Changing the family of an existing mapping is not an ordinary update; create a blue/green firewall and cut routes over after it is READY."
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

resource "terraform_data" "injected_endpoint_observation" {
  for_each = {
    for key, firewall in local.injected_firewalls : key => firewall
    if try(firewall.placement.vpc, null) != null
  }

  input = each.key

  lifecycle {
    precondition {
      condition = alltrue([
        for availability_zone, endpoint in each.value.placement.vpc.endpoint_subnets : anytrue([
          for sync_state in data.aws_networkfirewall_firewall.this[each.key].firewall_status[0].sync_states :
          sync_state.availability_zone == availability_zone && sync_state.attachment[0].subnet_id == endpoint.subnet_id
        ])
      ])
      error_message = "Injected firewall '${each.key}' observation metadata does not match firewall_status. Correct each AZ/subnet pair or omit placement.vpc and accept empty endpoint outputs."
    }
  }
}
