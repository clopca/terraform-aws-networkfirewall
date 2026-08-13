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

output "endpoint_ids_by_firewall_by_zone" {
  description = "Endpoint IDs by firewall key and caller-provided zone key. Injected firewalls return an empty zone map because inject mode does not accept managed placement metadata."
  value = {
    for firewall_key, records in local.endpoint_records_by_firewall : firewall_key => {
      for zone_key, record in records : zone_key => record.endpoint_id
    }
  }
}

output "endpoint_records_by_firewall_by_zone" {
  description = "Endpoint records by firewall key and caller-provided zone key. Shape: map(firewall_key, map(zone_key, object({ endpoint_id, subnet_id, status })))."
  value       = local.endpoint_records_by_firewall
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
