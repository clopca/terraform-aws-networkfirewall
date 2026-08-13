mock_provider "aws" {
  mock_resource "aws_networkfirewall_firewall" {
    defaults = {
      id   = "firewall-key-lifecycle-id"
      arn  = "arn:aws:network-firewall:us-east-1:123456789012:firewall/key-lifecycle"
      name = "key-lifecycle"
      firewall_status = [{
        sync_states = [{
          availability_zone = "us-east-1a"
          attachment = [{
            endpoint_id = "vpce-0123456789abcdef0"
            subnet_id   = "subnet-01111111111111111"
          }]
        }]
        transit_gateway_attachment_sync_states = []
      }]
    }
  }

  mock_resource "aws_networkfirewall_logging_configuration" {
    defaults = { id = "logging-key-lifecycle-id" }
  }

  mock_resource "aws_route" {
    defaults = { id = "route-key-lifecycle-id" }
  }
}

run "apply_public_collection_keys" {
  command   = apply
  state_key = "public-key-lifecycle"

  module { source = "./tests/fixtures/key-lifecycle" }

  variables {
    firewall_keys = ["alpha", "beta"]
    logging_keys  = ["alpha", "beta"]
    route_keys    = ["alpha", "beta"]
  }
}

run "reorder_preserves_public_collection_ids" {
  command   = plan
  state_key = "public-key-lifecycle"

  module { source = "./tests/fixtures/key-lifecycle" }

  variables {
    firewall_keys = ["beta", "alpha"]
    logging_keys  = ["beta", "alpha"]
    route_keys    = ["beta", "alpha"]
  }

  assert {
    condition = (
      output.firewall_ids.alpha == run.apply_public_collection_keys.firewall_ids.alpha &&
      output.logging_ids.alpha == run.apply_public_collection_keys.logging_ids.alpha &&
      output.route_ids.alpha == run.apply_public_collection_keys.route_ids.alpha
    )
    error_message = "Reordering public maps must preserve existing resource IDs."
  }
}

run "add_preserves_existing_public_collection_ids" {
  command   = plan
  state_key = "public-key-lifecycle"

  module { source = "./tests/fixtures/key-lifecycle" }

  variables {
    firewall_keys = ["alpha", "beta", "gamma"]
    logging_keys  = ["alpha", "beta", "gamma"]
    route_keys    = ["alpha", "beta", "gamma"]
  }

  assert {
    condition = (
      output.firewall_ids.alpha == run.apply_public_collection_keys.firewall_ids.alpha &&
      output.logging_ids.alpha == run.apply_public_collection_keys.logging_ids.alpha &&
      output.route_ids.alpha == run.apply_public_collection_keys.route_ids.alpha &&
      contains(keys(output.firewall_ids), "gamma") &&
      contains(keys(output.logging_ids), "gamma") &&
      contains(keys(output.route_ids), "gamma")
    )
    error_message = "Adding one key must preserve existing IDs and add only the new addresses."
  }
}

# This intentionally plans changed addresses without moved blocks. The saved-plan
# JSON gate documented in the upgrade guide rejects the resulting delete actions.
run "document_rename_without_moved_changes_addresses" {
  command   = plan
  state_key = "public-key-lifecycle"

  module { source = "./tests/fixtures/key-lifecycle" }

  variables {
    firewall_keys = ["renamed", "beta"]
    logging_keys  = ["renamed", "beta"]
    route_keys    = ["renamed", "beta"]
  }

  assert {
    condition = (
      !contains(keys(output.firewall_ids), "alpha") && contains(keys(output.firewall_ids), "renamed") &&
      !contains(keys(output.logging_ids), "alpha") && contains(keys(output.logging_ids), "renamed") &&
      !contains(keys(output.route_ids), "alpha") && contains(keys(output.route_ids), "renamed")
    )
    error_message = "A rename without moved blocks must be visible as old addresses disappearing and new addresses appearing."
  }
}

run "rename_with_moved_preserves_public_collection_ids" {
  command   = plan
  state_key = "public-key-lifecycle"

  module { source = "./tests/fixtures/key-lifecycle-moved" }

  variables {
    firewall_keys = ["renamed", "beta"]
    logging_keys  = ["renamed", "beta"]
    route_keys    = ["renamed", "beta"]
  }

  assert {
    condition = (
      output.firewall_ids.renamed == run.apply_public_collection_keys.firewall_ids.alpha &&
      output.logging_ids.renamed == run.apply_public_collection_keys.logging_ids.alpha &&
      output.route_ids.renamed == run.apply_public_collection_keys.route_ids.alpha
    )
    error_message = "Explicit moved blocks must preserve IDs across public key renames."
  }
}
