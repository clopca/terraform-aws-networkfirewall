# Basic firewall

Creates one protected AWS Network Firewall in an existing VPC with two caller-owned endpoint subnets. Both endpoint mappings are dual stack, and all state identity comes from the `primary`, `us-east-1a`, and `us-east-1b` keys.

Replace the example VPC, subnet, and policy ARNs before applying.

```shell
terraform init
terraform plan
```
