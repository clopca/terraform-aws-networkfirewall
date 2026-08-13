mock_provider "aws" {
  override_during = plan

  mock_resource "aws_route" {
    defaults = { id = "route-mock" }
  }
}

run "plan_ipv4_and_ipv6_routes" {
  command = plan

  module { source = "./modules/routes" }

  variables {
    endpoint_ids_by_zone = {
      "us-east-1a" = "vpce-0123456789abcdef0"
      "us-east-1b" = "vpce-0223456789abcdef0"
    }
    routes = {
      app-a-default-v4 = {
        route_table_id                   = "rtb-01111111111111111"
        endpoint_zone_key                = "us-east-1a"
        acknowledge_external_route_table = true
        destination                      = { ipv4_cidr = "0.0.0.0/0" }
      }
      app-a-default-v6 = {
        route_table_id                   = "rtb-01111111111111111"
        endpoint_zone_key                = "us-east-1a"
        acknowledge_external_route_table = true
        destination                      = { ipv6_cidr = "::/0" }
      }
      app-b-default-v4 = {
        route_table_id                   = "rtb-02222222222222222"
        endpoint_zone_key                = "us-east-1b"
        acknowledge_external_route_table = true
        destination                      = { ipv4_cidr = "10.0.0.0/8" }
      }
    }
  }

  assert {
    condition = (
      toset(keys(aws_route.this)) == toset(["app-a-default-v4", "app-a-default-v6", "app-b-default-v4"]) &&
      aws_route.this["app-a-default-v4"].vpc_endpoint_id == "vpce-0123456789abcdef0" &&
      aws_route.this["app-b-default-v4"].vpc_endpoint_id == "vpce-0223456789abcdef0"
    )
    error_message = "Routes must preserve caller keys and select the endpoint for the declared zone."
  }
}

run "reject_missing_endpoint_zone" {
  command = plan
  module { source = "./modules/routes" }
  variables {
    endpoint_ids_by_zone = { a = "vpce-a" }
    routes = {
      bad = {
        route_table_id                   = "rtb-1"
        endpoint_zone_key                = "b"
        acknowledge_external_route_table = true
        destination                      = { ipv4_cidr = "0.0.0.0/0" }
      }
    }
  }
  expect_failures = [terraform_data.route_contract["bad"]]
}

run "reject_multiple_route_destinations" {
  command = plan
  module { source = "./modules/routes" }
  variables {
    endpoint_ids_by_zone = { a = "vpce-a" }
    routes = {
      bad = {
        route_table_id                   = "rtb-1"
        endpoint_zone_key                = "a"
        acknowledge_external_route_table = true
        destination                      = { ipv4_cidr = "0.0.0.0/0", ipv6_cidr = "::/0" }
      }
    }
  }
  expect_failures = [terraform_data.route_contract["bad"]]
}

run "reject_invalid_destination_family" {
  command = plan
  module { source = "./modules/routes" }
  variables {
    endpoint_ids_by_zone = { a = "vpce-a" }
    routes = {
      bad = {
        route_table_id                   = "rtb-1"
        endpoint_zone_key                = "a"
        acknowledge_external_route_table = true
        destination                      = { ipv4_cidr = "2001:db8::/64" }
      }
    }
  }
  expect_failures = [terraform_data.route_contract["bad"]]
}

run "reject_duplicate_table_destination" {
  command = plan
  module { source = "./modules/routes" }
  variables {
    endpoint_ids_by_zone = { a = "vpce-a", b = "vpce-b" }
    routes = {
      first = {
        route_table_id                   = "rtb-1"
        endpoint_zone_key                = "a"
        acknowledge_external_route_table = true
        destination                      = { ipv4_cidr = "10.0.0.0/8" }
      }
      second = {
        route_table_id                   = "rtb-1"
        endpoint_zone_key                = "b"
        acknowledge_external_route_table = true
        destination                      = { ipv4_cidr = "10.0.0.0/8" }
      }
    }
  }
  expect_failures = [terraform_data.route_contract["first"], terraform_data.route_contract["second"]]
}

run "reject_prefix_list_endpoint_target" {
  command = plan
  module { source = "./modules/routes" }
  variables {
    endpoint_ids_by_zone = { a = "vpce-a" }
    routes = {
      bad = {
        route_table_id                   = "rtb-1"
        endpoint_zone_key                = "a"
        acknowledge_external_route_table = true
        destination                      = { prefix_list_id = "pl-0123456789abcdef0" }
      }
    }
  }
  expect_failures = [terraform_data.route_contract["bad"]]
}

run "reject_slash_in_route_key" {
  command = plan
  module { source = "./modules/routes" }
  variables {
    endpoint_ids_by_zone = { a = "vpce-a" }
    routes = {
      "bad/key" = {
        route_table_id                   = "rtb-1"
        endpoint_zone_key                = "a"
        acknowledge_external_route_table = true
        destination                      = { ipv4_cidr = "0.0.0.0/0" }
      }
    }
  }
  expect_failures = [terraform_data.route_contract["bad/key"]]
}

run "reject_external_route_table_without_acknowledgement" {
  command = plan
  module { source = "./modules/routes" }
  variables {
    endpoint_ids_by_zone = { a = "vpce-a" }
    routes = {
      bad = {
        route_table_id    = "rtb-1"
        endpoint_zone_key = "a"
        destination       = { ipv4_cidr = "0.0.0.0/0" }
      }
    }
  }
  expect_failures = [terraform_data.route_contract["bad"]]
}
