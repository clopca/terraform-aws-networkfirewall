# ADR 0010: Rule-group ownership boundary

## Status

Implemented in 2.0

## Decision

Policy control is a pure ARN-binding layer. It owns policy structure—slots, priorities, rollout posture, incident overrides, HOME_NET, TLS presence, and engine options—but never rule content. A content update to any referenced rule group therefore does not appear in a policy-control plan; the blast radius of its apply is structural only.

Rule groups support three first-class management models:

| Model | ARN source | Structure owner | Content owner and cadence | Terraform behavior |
| --- | --- | --- | --- | --- |
| IaC pure | `modules/rule-groups`, `content_management = "terraform"` | Terraform security release | Terraform security release; commit/apply cadence | Structure and content drift are planned. External attestation or explicit `aws_apply` validates the source path. |
| AWS managed | AWS managed StrictOrder catalog | Policy binding in Terraform | AWS; vendor service cadence | Terraform binds ARN and caller-declared metadata. `DROP_TO_ALERT` is available only here. |
| Dynamic SecOps | `modules/rule-groups`, `content_management = "external"`, or another external publisher | Terraform owns name, capacity, type, rule order, encryption, and tags | SOC/SOAR pipeline through `UpdateRuleGroup`; seconds-to-minutes cadence | Seed content bootstraps creation; subsequent content changes are ignored so Terraform does not overwrite live IOCs/signatures. |

Choose IaC pure for reviewed rules promoted with application releases. Choose AWS managed for AWS-maintained threat intelligence with no customer source lifecycle. Choose dynamic SecOps for high-frequency IOC/signature updates that must not wait for infrastructure releases; keep structural changes in Terraform and audit API writes separately.

`source_validation` does not apply to dynamic external content. The live source and its evidence belong to the external pipeline. Terraform-owned `attested` mode requires an external manifest URI and bundle digest; deriving the expected digest from the same input file is self-attestation and is not evidence.

## Verification boundary

The AWS provider has no `data.aws_networkfirewall_rule_group`. Terraform cannot verify that an injected ARN exists or discover its type, rule order, capacity, behavior, or content. Every injected group and policy slot therefore carries caller-declared metadata as an attestation. The module checks internal consistency and quotas; AWS remains the apply-time authority.
