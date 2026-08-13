resource "aws_networkfirewall_firewall" "this" {
  for_each = local.created_firewalls

  name                = each.value.name != null ? each.value.name : each.key
  description         = each.value.description
  firewall_policy_arn = each.value.policy_arn != null ? each.value.policy_arn : "arn:aws:network-firewall:us-east-1:000000000000:firewall-policy/invalid"
  vpc_id              = try(each.value.placement.vpc.vpc_id, null)

  delete_protection                   = each.value.protections.delete
  firewall_policy_change_protection   = each.value.protections.policy_change
  subnet_change_protection            = each.value.protections.subnet_change
  availability_zone_change_protection = each.value.protections.availability_zone_change
  enabled_analysis_types              = each.value.enabled_analysis_types

  dynamic "subnet_mapping" {
    for_each = try(each.value.placement.vpc.endpoint_subnets, {})

    content {
      subnet_id       = subnet_mapping.value.subnet_id
      ip_address_type = subnet_mapping.value.ip_address_type
    }
  }

  dynamic "encryption_configuration" {
    for_each = each.value.encryption.type == "CUSTOMER_KMS" ? [each.value.encryption] : []

    content {
      type   = "CUSTOMER_KMS"
      key_id = encryption_configuration.value.key_arn
    }
  }

  tags = each.value.tags

  depends_on = [terraform_data.firewall_contract]
}

data "aws_networkfirewall_firewall" "this" {
  for_each = local.injected_firewalls

  arn = each.value.arn != null ? each.value.arn : "arn:aws:network-firewall:us-east-1:000000000000:firewall/invalid"

  depends_on = [terraform_data.firewall_contract]
}
