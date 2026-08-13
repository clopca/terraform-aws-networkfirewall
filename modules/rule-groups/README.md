# Rule groups

This public module creates or injects caller-keyed AWS Network Firewall rule groups. `rules_string` (normally `file(...)`) is the primary lane; domain lists, native stateful 5-tuples, and stateless rules are closed alternatives. Created group `name`, `type`, `capacity`, and `rule_order` are durable replacement identity. Capacity is required and limited to `1..30000`; the module supports only `STRICT_ORDER` for stateful groups.

## Content ownership

`content_management = "terraform"` (default) makes Terraform own both structure and content, so content drift appears in plans. `content_management = "external"` makes Terraform own only existence and structural identity while a SOC/SOAR pipeline updates content through `UpdateRuleGroup`; the supplied source is bootstrap seed content and later content changes are ignored. External content cannot use `source_validation` because the live content is outside this state boundary.

Injected groups use `create = false`, an ARN, and mandatory declared metadata `{type, rule_order, declared_capacity, kind}`. The AWS provider has no `data.aws_networkfirewall_rule_group`, so the module cannot verify existence or metadata at plan time.

## Suricata validation

Declare every referenced variable in `required_ip_sets` and `required_port_sets`; missing or empty bindings fail plan and name the missing keys. For `rules_string`, the module extracts every `sid:` with `regexall`, rejects duplicates, and optionally enforces `sid_range`. This is deterministic validation only: AWS remains the Suricata parser.

Terraform-owned content requires one validation mode:

- `attested`: requires an external `manifest_uri` and a 64-character `bundle_sha256`. The manifest must be produced by CI; computing the expected digest from the same local file is self-attestation and is not accepted as evidence.
- `aws_apply`: explicit opt-in that lets AWS be the first complete syntax validator; use it only in isolated validation or controlled break-glass workflows.

AWS-owned encryption omits the provider block. Customer KMS renders it explicitly.
