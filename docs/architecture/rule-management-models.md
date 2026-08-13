# Rule-management models

```mermaid
flowchart LR
  subgraph IaC[IaC pure]
    PR[Reviewed rule bundle] --> TF[Terraform]
    TF --> IACRG[Created rule group: structure + content]
    IACRG --> IACPLAN[Content drift appears in plan]
  end

  subgraph Managed[AWS managed]
    AWS[AWS content lifecycle] --> MRG[Managed rule group ARN]
    TF2[Terraform metadata + binding] --> MRG
    MRG --> DTOA[Managed-only DROP_TO_ALERT option]
  end

  subgraph SecOps[Dynamic SecOps]
    TF3[Terraform structure + seed] --> ERG[Externally managed-content group]
    SOC[SOC/SOAR UpdateRuleGroup] --> ERG
    ERG --> IGN[Post-bootstrap content drift ignored]
  end
```

```mermaid
flowchart TB
  BUNDLE[Rule bundle] --> DIGEST[Bundle SHA-256]
  EVIDENCE[Independent manifest + digest/signature] --> VERIFY[CI verification]
  DIGEST --> VERIFY
  VERIFY --> AWSVAL[AWS parser and match/no-match tests]
  AWSVAL --> RELEASE[Versioned rule group]
  RELEASE --> RECORDS[rule_group_records]
  RECORDS --> POLICY[Policy-control release]
```

`attested` validates evidence shape only. Trust comes from independent production,
signature/digest verification, immutable build context, and reviewed AWS test
results. See [rule management](../rule-management.md).
