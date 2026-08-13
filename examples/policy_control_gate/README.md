# Policy control gate

Creates four immutable policy releases: observation candidate, selective active, enforced last-known-good, and an incident release that observes all stateful groups except one force-enforced customer slot. The example demonstrates managed-only `DROP_TO_ALERT`, customer alert-only ARN switching, incident precedence, and candidate/active/LKG selection by ARN.

The ARNs are illustrative. Supply real AWS-managed, `modules/rule-groups`, or SOC-owned external rule-group ARNs before apply.
