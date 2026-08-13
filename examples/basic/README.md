# Basic firewall

Creates one protected AWS Network Firewall in an existing VPC with two caller-owned endpoint subnets. Both endpoint mappings are new dual-stack identities and set `address_family_migration_ack = true`; all state identity comes from the `primary`, `us-east-1a`, and `us-east-1b` keys. Never add that acknowledgement merely to flip an existing mapping—use a new blue/green firewall key.

Replace the example VPC, subnet, and policy ARNs before applying.

```shell
terraform init
terraform plan
```
