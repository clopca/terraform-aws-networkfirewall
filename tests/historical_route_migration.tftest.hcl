mock_provider "aws" {
  mock_resource "aws_route" {
    defaults = { id = "historical-route-id" }
  }
}

run "apply_all_pre_v1_route_addresses" {
  command   = apply
  state_key = "pre-v1-route-chain"
  module { source = "./tests/fixtures/pre-v1-routes" }

  assert {
    condition = (
      length(output.egress_route_ids) == 6 &&
      length(output.without_egress_route_ids) == 6
    )
    error_message = "The pre-v1 fixture must seed all six indices in both historical route families."
  }
}

run "plan_complete_historical_chain" {
  command   = plan
  state_key = "pre-v1-route-chain"
  module { source = "./examples/migration_pre_v1_routes" }

  assert {
    condition = alltrue([
      for index in ["0", "5"] :
      output.egress_route_ids[index] == run.apply_all_pre_v1_route_addresses.egress_route_ids[index]
    ])
    error_message = "centralized_inspection_with_egress boundary indices 0 and 5 must survive old→v1→semantic-key moves."
  }

  assert {
    condition = alltrue([
      for index in ["0", "5"] :
      output.without_egress_route_ids[index] == run.apply_all_pre_v1_route_addresses.without_egress_route_ids[index]
    ])
    error_message = "centralized_inspection_without_egress boundary indices 0 and 5 must survive old→v1→semantic-key moves."
  }
}
