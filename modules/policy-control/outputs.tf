output "policy_arns" {
  description = "Effective firewall-policy ARNs by immutable release key."
  value       = local.policy_arns
}

output "effective_releases" {
  description = "Compiled binding posture by release, including effective ARNs and managed-only overrides. Rule-group content is intentionally absent."
  value       = local.effective_releases
}

output "resources" {
  description = "Internal firewall-policy resources. This shape is not semver-protected."
  value       = { firewall_policies = aws_networkfirewall_firewall_policy.this }
}
