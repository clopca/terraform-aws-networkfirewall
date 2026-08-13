## Summary

<!-- What user outcome changes, and why? -->

## Public contract and lifecycle

- Affected root/submodule/example/docs:
- Caller-key or Terraform-address impact:
- Create/inject ownership impact:
- Replacement, endpoint, route, policy, logging, or rule-content impact:
- Output tier/semver impact:
- Migration and rollback:

## Validation

<!-- List exact commands and results. Do not write only "CI". -->

- [ ] `terraform fmt -check -recursive`
- [ ] Root init/validate
- [ ] All public submodule init/validate
- [ ] `./scripts/validate-examples.sh`
- [ ] `terraform test -no-color`
- [ ] `tflint --recursive`
- [ ] Documentation, contract, migration, and mutation guards
- [ ] `git diff --check`

Test count/result:

Known exclusions or checks not run:

## Documentation and release

- [ ] Updated `.header.md` and regenerated `README.md` when required
- [ ] Updated guides/examples/diagrams for changed behavior
- [ ] Updated upgrade guidance for state or breaking changes
- [ ] Updated `CHANGELOG.md`
- [ ] Added or updated an ADR for a durable architecture decision
- [ ] Documented placeholders, costs, ownership, and static-validation limits

## Safety checklist

- [ ] No credentials, Terraform state, sensitive plans, customer data, or private rule content
- [ ] No unintended delete/replace actions in migration examples
- [ ] Forward and return routing are explicit where applicable
- [ ] Managed/customer rule behavior and incident expiry are described honestly
- [ ] Product bugs discovered but intentionally excluded are listed below

## Exclusions and follow-up

<!-- Product bugs, deferred work, or intentional non-goals. -->
