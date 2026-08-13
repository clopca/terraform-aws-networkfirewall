# Module composition

VPC v5 supplies the VPC ID and firewall subnet IDs by AZ to the root module.
Rule-group records flow from `modules/rule-groups` to
`modules/policy-control`; the selected policy ARN then flows to the root
firewall. The root endpoint map feeds either VPC v5 native routes or
`modules/routes`, while the firewall ARN feeds `modules/logging`. Existing
firewall, policy, and rule ARNs may enter at their explicit inject boundaries;
S3 buckets and Firehose streams remain external to logging.


## Ownership rules

- Root: firewall create/inject boundary, placement, protections, and endpoint
  readiness contract.
- Rule groups: structure plus Terraform-managed content, or structure plus
  externally managed live content.
- Policy control: immutable policy releases and incident posture; never rule
  content.
- Logging: one effective logging configuration per firewall and optional
  CloudWatch log groups.
- Routes: only explicitly declared routes in route tables owned elsewhere.
- VPC v5: network primitives and native routes in its state.

Stable maps, rather than provider objects, cross these boundaries. See
[how to use outputs](../how-to-use-outputs.md).
