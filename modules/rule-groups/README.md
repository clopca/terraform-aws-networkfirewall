# Rule groups

This public module creates or injects caller-keyed AWS Network Firewall rule groups. `rules_string` (normally `file(...)`) is the primary lane; domain lists, native stateful 5-tuples, and stateless rules are closed alternatives. Created group `name`, `type`, `capacity`, and `rule_order` are durable replacement identity. Capacity is required and limited to `1..30000`; the module supports only `STRICT_ORDER` for stateful groups.

## Content ownership

`content_management = "terraform"` (default) makes Terraform own both structure and content, so content drift appears in plans. `content_management = "external"` makes Terraform own only existence and structural identity while a SOC/SOAR pipeline updates content through `UpdateRuleGroup`; the supplied source is bootstrap seed content and later content changes are ignored. External content cannot use `source_validation` because the live content is outside this state boundary.

Injected groups use `create = false`, an ARN, and mandatory declared metadata `{type, rule_order, declared_capacity, kind}`. The AWS provider has no `data.aws_networkfirewall_rule_group`, so the module cannot verify existence or metadata at plan time.

## Suricata validation

Declare every referenced variable in `required_ip_sets` and `required_port_sets`; missing or empty bindings fail plan and name the missing keys. For `rules_string`, the module removes full-line comments and quoted string contents before extracting active `sid:` options, rejects duplicates, and optionally enforces `sid_range`. This is a deliberately narrow scanner, not a complete Suricata parser; AWS remains the syntax authority.

Terraform-owned content requires one validation mode:

- `attested`: requires a non-empty `manifest_uri` and a 64-character `bundle_sha256`, but Terraform validates only their shape. It cannot determine whether `bundle_sha256` came from `filesha256` of the same source, so evidence independence is a process guarantee, not a type-system guarantee. The correct pattern is a separately published manifest with its own digest or signature, the bundle digest, validation job and commit identity, and relevant AWS context; CI must verify that manifest and compare its bundle digest before plan/apply.
- `aws_apply`: explicit opt-in that lets AWS be the first complete syntax validator; use it only in isolated validation or controlled break-glass workflows.

AWS-owned encryption omits the provider block. Customer KMS renders it explicitly.
