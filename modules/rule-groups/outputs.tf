output "rule_group_arns" {
  description = "Effective rule-group ARNs by caller key."
  value       = local.rule_group_arns
}

output "rule_group_records" {
  description = "Declared rule-group identity and ownership metadata for policy-control composition. Injected values are caller attestations, not remote discovery."
  value       = local.rule_group_records
}

output "resources" {
  description = "Internal rule-group resources. This shape is not semver-protected."
  value = {
    terraform_content = aws_networkfirewall_rule_group.terraform_content
    external_content  = aws_networkfirewall_rule_group.external_content
  }
}
