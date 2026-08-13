# Security policy

## Reporting a vulnerability

Do not open a public GitHub issue for a suspected vulnerability. Report AWS or
AWS open-source security vulnerabilities through the
[AWS vulnerability reporting process](https://aws.amazon.com/security/vulnerability-reporting/).
Include the repository name, affected version/commit, impact, reproduction steps,
and any proposed mitigation. Remove credentials, account IDs, customer data,
firewall rule content, logs, and other sensitive material unless the secure
reporting channel explicitly requests them.

For questions about AWS Network Firewall service behavior that are not module
vulnerabilities, use AWS Support. For non-sensitive module bugs, use the public
bug report form.

## Supported versions

Security fixes are made on the currently supported major line and documented in
[CHANGELOG.md](CHANGELOG.md). Check the
[Terraform Registry](https://registry.terraform.io/modules/aws-ia/networkfirewall/aws/latest)
for the latest published version before reporting or deploying.

| Version | Status |
|---|---|
| 2.x | Supported |
| 1.x and earlier | Upgrade to a supported release |

## Sensitive configuration

- Do not commit Terraform state, plans containing sensitive data, credentials,
  private rule bundles, customer CIDRs, or production log samples.
- Redact account IDs, ARNs, IP addresses, hostnames, S3 paths, and ticket links
  from public reports when they identify a real environment.
- Use least-privilege AWS credentials and a non-production account for
  reproduction.
- Keep rule validation evidence and dynamic SecOps delivery records in approved
  stores with independent integrity controls.
