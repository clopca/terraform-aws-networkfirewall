# Contributing

Thank you for improving the AWS Network Firewall Terraform module. Contributions
should preserve explicit ownership, stable caller keys, zonal routing identity,
non-destructive migration, and honest validation boundaries.

## Before opening a change

- Search existing issues and pull requests.
- Use the feature request form for a new public input, output, module boundary,
  ownership model, or lifecycle behavior.
- Use [AWS vulnerability reporting](SECURITY.md) for security vulnerabilities;
  do not disclose them in a public issue.
- Keep product behavior changes separate from documentation-only changes when
  practical.

## Prerequisites

- Terraform `>= 1.7`.
- AWS provider `>= 6.59, < 7.0` (installed by `terraform init`).
- TFLint with the repository's configured plugins.
- `terraform-docs` `0.24.0` when changing root inputs, outputs, requirements, or
  `.header.md`.
- Bash and Python 3 for repository guards.

AWS credentials are not required for formatting, static validation, mocked
Terraform tests, or documentation smoke tests. Use a non-production account for
any real plan/apply and follow the example cost warnings.

## Development workflow

1. Create a branch from the current default branch.
2. Make the smallest coherent change.
3. Add or update Terraform-native tests for behavior and contract changes.
4. Update relevant docs, examples, ADRs, and upgrade guidance.
5. If `.header.md` or root Terraform changes, run `terraform-docs .` and commit
   the generated `README.md`.
6. Run the complete checks below.
7. Open a pull request using the repository template.

Do not edit generated README input/output tables by hand. `.header.md` is the
human-authored root prose source, and `terraform-docs` generates `README.md`.

## Required checks

```shell
terraform fmt -check -recursive
terraform init -backend=false -lockfile=readonly
terraform validate -no-color

for module in logging routes rule-groups policy-control; do
  terraform -chdir="modules/${module}" init -backend=false -lockfile=readonly
  terraform -chdir="modules/${module}" validate -no-color
done

./scripts/validate-examples.sh
terraform test -no-color
tflint --init
tflint --recursive
./scripts/check-docs.sh
./scripts/check-contract.sh
./scripts/test-migration-plan-guard.sh
./scripts/test-policy-managed-override-mutation.sh
./scripts/test-product-moved-mutation.sh
git diff --check
```

The example validator discovers every first-level directory under `examples/`.
The VPC v5 golden path keeps its canonical future Registry source; validation
rewrites only that source/version to the checked-in documentation-contract
fixture.

## Public contract changes

Explain in the pull request:

- caller-key and Terraform-address impact;
- create/inject ownership impact;
- ForceNew, endpoint, route, policy, or logging lifecycle impact;
- output tier and semver commitment;
- migration steps and rollback;
- whether behavior differs for managed and customer rule groups;
- expected plans and negative tests.

Breaking changes require an upgrade path and major-version treatment. Do not add
new consumers of the deprecated `aws_network_firewall` output or Tier 3
`resources` shapes.

## Examples and documentation

Every new example should include:

- prerequisites, placeholders, and cost warning;
- ownership and route matrices where applicable;
- precise forward and return path descriptions with the relevant HCL;
- init/validate/plan guidance and runtime verification;
- an explicit statement that static validation does not prove traffic or AWS
  resource existence.

Public documentation must not contain local paths, unpublished analysis labels,
credentials, customer data, or claims stronger than the tested contract.

## Commits and pull requests

Use focused commits with descriptive imperative subjects. Keep unrelated
formatting out of functional changes. The pull request must list tests run,
known exclusions, documentation impact, and any product bug discovered but not
fixed.

By contributing, you agree that your contributions are licensed under this
repository's [LICENSE](LICENSE).
