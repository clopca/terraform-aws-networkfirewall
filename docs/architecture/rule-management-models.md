# Rule-management models

In IaC-pure mode, a reviewed bundle enters Terraform and both structural and
content drift appear in plans. For AWS managed groups, AWS owns changing
content while Terraform binds the managed ARN and caller-declared metadata;
only this model can use `DROP_TO_ALERT`. In dynamic SecOps mode, Terraform
creates the structural identity and seed content, then a SOC/SOAR system updates
live content through `UpdateRuleGroup` while Terraform ignores post-bootstrap
content drift.


A release verifies the bundle SHA-256 against an independently produced
manifest digest or signature, records immutable build and AWS validation
context, runs parser plus match/no-match tests, and publishes a versioned rule
group. `rule_group_records` carries that group identity and declared metadata
into the policy-control release.


`attested` validates evidence shape only. Trust comes from independent production,
signature/digest verification, immutable build context, and reviewed AWS test
results. See [rule management](../rule-management.md).
