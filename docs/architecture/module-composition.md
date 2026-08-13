# Module composition

```mermaid
flowchart TB
  subgraph External[External or VPC stack]
    VPC[VPC v5: VPC, subnets, route tables, NAT, IGW]
    EXT[Existing firewall/policy/rule ARNs]
    DEST[S3 bucket and Firehose stream]
  end

  RG[modules/rule-groups] -->|rule_group_records| PC[modules/policy-control]
  PC -->|policy_arns| ROOT[Network Firewall root]
  EXT --> ROOT
  VPC -->|vpc_id and firewall subnet IDs by AZ| ROOT
  ROOT -->|firewall_arns| LOG[modules/logging]
  DEST --> LOG
  ROOT -->|endpoint IDs by firewall by AZ| VROUTE[VPC v5 native routes]
  ROOT -->|endpoint IDs by AZ| ROUTES[modules/routes]
  VPC --> VROUTE
  VPC -->|external route-table IDs and AZs| ROUTES
```

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
