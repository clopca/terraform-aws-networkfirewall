mock_provider "aws" {
  mock_resource "aws_networkfirewall_firewall" {
    defaults = {
      arn = "arn:aws:network-firewall:us-east-1:123456789012:firewall/create-inject-composition-source"
    }
  }
}

run "resource_arn_can_feed_injected_observation" {
  command = plan

  module {
    source = "./tests/fixtures/create-inject-composition"
  }

  assert {
    condition     = output.injected_firewall_keys == ["observed"]
    error_message = "A resource-derived firewall ARN must preserve the static injected-firewall key during plan."
  }
}
