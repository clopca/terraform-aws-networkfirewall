# VPC v5 documentation-contract fixture

This fixture exists only to statically validate the pre-release
`examples/end_to_end_vpc_v5` composition in CI and source archives. It models the
small VPC v5 input/output surface consumed by that example and creates no AWS
resources.

It is not a VPC implementation, test double for apply behavior, or substitute
for validating against the released `aws-ia/vpc/aws` module. The example keeps
the future Registry source; `scripts/validate-examples.sh` copies the example to
a temporary directory and rewrites only that VPC source/version to this fixture.
