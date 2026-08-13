# Versioned Suricata rule group

This example creates one STRICT_ORDER stateful rule group from `egress.rules`
and binds environment-specific networks and ports through typed sets. Use it when
Terraform owns rule structure and content and a separate security release system
produces validation evidence.

## What this demonstrates

- `rule_groups.egress-v1` is the immutable caller key for this rule release.
- `source.rules_string = file("${path.module}/egress.rules")` selects the
  Suricata source lane.
- `ip_sets.WORKLOADS` and `port_sets.WEB_PORTS` bind environment values without
  rewriting the rule bundle.
- `required_ip_sets` and `required_port_sets` reject missing or empty bindings.
- `requires_home_net = true` propagates HOME_NET requirements through
  `rule_group_records` into policy-control composition.
- `sid_range = { min = 4100000, max = 4100099 }` constrains rule identity for
  this release.
- `source_validation.mode = "attested"` validates evidence shape but does not
  prove that the manifest or digest was produced independently.

Both directions of an established flow are evaluated when this group is bound to
a policy. Independent AWS parser, match, and no-match tests remain required.

## Relevant configuration

The complete deployable configuration is in [`main.tf`](./main.tf). The typed
bindings and validation evidence are the distinguishing portion:

```hcl
rule_groups = {
  egress-v1 = {
    name       = "inspection-egress-v1"
    type       = "STATEFUL"
    capacity   = 500
    rule_order = "STRICT_ORDER"

    source = {
      rules_string = file("${path.module}/egress.rules")
    }

    ip_sets = {
      WORKLOADS = ["10.0.0.0/8"]
    }
    port_sets = {
      WEB_PORTS = ["80", "443"]
    }
    required_ip_sets   = ["WORKLOADS"]
    required_port_sets = ["WEB_PORTS"]
    requires_home_net  = true
    sid_range          = { min = 4100000, max = 4100099 }

    source_validation = {
      mode          = "attested"
      manifest_uri  = "s3://security-rule-attestations/egress-v1/manifest.json"
      bundle_sha256 = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    }
  }
}
```

## Prerequisites and cost

- Replace the manifest URI and digest with independently produced evidence.
- Validate the rule bundle with AWS in the target account and Region.
- Applying creates a billable rule group; a policy and firewall are not created.

## Run

```shell
terraform init
terraform validate
terraform plan -out=tfplan
```

Confirm capacity, SID allocation, HOME_NET, and match/no-match results before
binding `rule_group_records` to a policy release.
