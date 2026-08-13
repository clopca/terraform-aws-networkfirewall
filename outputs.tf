# Tier 1: stable composition handles.
output "firewall_arns" {
  description = "Firewall ARNs by caller key."
  value = {
    for key, firewall in var.firewalls : key => (
      firewall.create ? aws_networkfirewall_firewall.this[key].arn : data.aws_networkfirewall_firewall.this[key].arn
    )
  }
}

output "firewall_ids" {
  description = "Firewall IDs by caller key."
  value = {
    for key, firewall in var.firewalls : key => (
      firewall.create ? aws_networkfirewall_firewall.this[key].id : data.aws_networkfirewall_firewall.this[key].id
    )
  }
}

output "firewall_names" {
  description = "Firewall names by caller key."
  value = {
    for key, firewall in var.firewalls : key => (
      firewall.create ? aws_networkfirewall_firewall.this[key].name : data.aws_networkfirewall_firewall.this[key].name
    )
  }
}

output "firewall_policy_arns" {
  description = "Effective firewall policy ARNs by caller key."
  value = {
    for key, firewall in var.firewalls : key => (
      firewall.create ? aws_networkfirewall_firewall.this[key].firewall_policy_arn : data.aws_networkfirewall_firewall.this[key].firewall_policy_arn
    )
  }
}

output "vpc_endpoint_ids_by_firewall_by_az" {
  description = "VPC endpoint IDs by firewall key and input Availability Zone name."
  value = {
    for firewall_key, records in local.vpc_endpoint_records_by_firewall : firewall_key => {
      for availability_zone, record in records : availability_zone => record.vpc_endpoint_id
    }
  }
}

output "vpc_endpoint_records_by_firewall_by_az" {
  description = "VPC endpoint records by firewall key and input Availability Zone name, including AZ ID and readiness guarantee."
  value       = local.vpc_endpoint_records_by_firewall
}

# Tier 2: v1 bridge, removed in v3.
output "aws_network_firewall" {
  description = "DEPRECATED v1-compatible provider object when a created firewall uses key 'primary'; otherwise null. Use Tier 1 outputs."
  value       = try(aws_networkfirewall_firewall.this["primary"], null)
}

# Tier 3: escape hatch without a stable shape guarantee.
output "resources" {
  description = "Internal firewall resource and data-source collections. This shape is not semver-protected."
  value = {
    firewalls          = aws_networkfirewall_firewall.this
    injected_firewalls = data.aws_networkfirewall_firewall.this
  }
}
