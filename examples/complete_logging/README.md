# Firewall with ALERT, FLOW, and TLS logging

This example creates one firewall, one managed CloudWatch log group, and one
logging configuration with ALERT, FLOW, and TLS destinations. Use it to compose
firewall identity with mixed destination ownership while keeping durable S3 and
Firehose infrastructure outside the logging submodule.

## What this demonstrates

- `logging_configurations.primary.firewall_arn` consumes the stable root
  `firewall_arns.primary` output.
- `monitoring_dashboard = true` enables the Network Firewall monitoring
  dashboard for the effective logging configuration.
- `logs.alerts.log_type = "ALERT"` creates a CloudWatch destination and a log
  group with 90-day retention.
- `logs.flows.destination.s3` injects an existing bucket name and prefix; the
  bucket, policy, encryption, and lifecycle remain external.
- `logs.tls.destination.firehose` injects an existing delivery-stream name; the
  stream and its IAM/S3 dependencies remain external.
- `logging_destination_records.primary` returns normalized destination handles
  without exposing provider objects.

Forward and return packets traverse the same externally routed firewall path.
The firewall sends each enabled log class to its configured destination;
logging composition does not create or change traffic routes.

## Relevant configuration

The complete deployable configuration is in [`main.tf`](./main.tf). The mixed
logging ownership is the distinguishing portion:

```hcl
logging_configurations = {
  primary = {
    firewall_arn         = module.network_firewall.firewall_arns.primary
    monitoring_dashboard = true
    logs = {
      alerts = {
        log_type = "ALERT"
        destination = {
          cloudwatch = {
            log_group_name    = "/aws/network-firewall/example/alerts"
            retention_in_days = 90
          }
        }
      }
      flows = {
        log_type = "FLOW"
        destination = {
          s3 = {
            bucket_name = "replace-with-existing-log-bucket"
            prefix      = "network-firewall/flow"
          }
        }
      }
      tls = {
        log_type = "TLS"
        destination = {
          firehose = {
            delivery_stream_name = "replace-with-existing-delivery-stream"
          }
        }
      }
    }
  }
}
```

## Prerequisites and cost

- Replace the VPC, subnet, policy, bucket, and Firehose values before planning.
- The external S3 bucket and Firehose stream need Network Firewall delivery
  permissions in the selected Region.
- Once TLS log delivery starts, AWS adds the tag `LogDeliveryEnabled = "true"`
  to the delivery stream. If the stream is managed by Terraform elsewhere, that
  state shows a perpetual one-tag diff. Add this to the
  `aws_kinesis_firehose_delivery_stream` resource that owns the stream:

  ```hcl
  lifecycle {
    ignore_changes = [tags["LogDeliveryEnabled"]]
  }
  ```
- Applying creates one firewall endpoint and one CloudWatch log group. Network
  Firewall, CloudWatch ingestion/retention, S3, Firehose, and transfer charges
  can apply.

## Run

```shell
terraform init
terraform validate
terraform plan -out=tfplan
```

After apply, verify current records in all three destinations and test both
traffic directions. Static validation cannot verify destination existence,
permissions, delivery, or traffic.
