# Policy control gate

Creates four immutable policy releases: observation candidate, selective active, enforced last-known-good, and an incident release that observes all stateful groups except one force-enforced customer slot. The example demonstrates managed-only `DROP_TO_ALERT`, customer alert-only ARN switching, incident precedence, and candidate/active/LKG selection by ARN.

The ARNs are illustrative. Supply real AWS-managed, `modules/rule-groups`, or SOC-owned external rule-group ARNs before apply.

## Release and traffic flow

Managed and customer rule-group ARNs feed four immutable policy releases. The
firewall binds exactly one candidate, active, last-known-good, or incident ARN;
forward and return packets use the same selected policy, while ALERT and FLOW
telemetry provide promotion and rollback evidence.


Managed groups can use `DROP_TO_ALERT`; blocking customer groups use their
alert-only observation ARN. Stateless groups remain enforced. Incident expiry is
not automatic. Validate candidate digest/evidence, retain the LKG ARN, and test
both traffic directions before promotion. Static validation does not verify the
illustrative ARNs, metadata attestations, policy behavior, or traffic.
