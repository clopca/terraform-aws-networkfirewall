# Firewall with complete logging

Creates one firewall, one CloudWatch log group, and one logging configuration containing ALERT, FLOW, and TLS destinations. The S3 bucket and Firehose delivery stream are injected because their durable storage, IAM, encryption, and retention lifecycles remain externally owned.

Replace the example VPC, subnet, policy, bucket, and delivery-stream values before applying.

```shell
terraform init
terraform plan
```
