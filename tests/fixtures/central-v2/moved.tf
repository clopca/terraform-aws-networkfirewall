moved {
  from = module.nfw.module.logging[0].aws_networkfirewall_logging_configuration.anfw_logs
  to   = module.nfw_logging.aws_networkfirewall_logging_configuration.this["primary"]
}

moved {
  from = module.nfw.aws_route.connectivity_to_firewall_endpoint[0]
  to   = module.nfw_routes.aws_route.this["tgw-a-default"]
}
moved {
  from = module.nfw.aws_route.connectivity_to_firewall_endpoint[1]
  to   = module.nfw_routes.aws_route.this["tgw-b-default"]
}

moved {
  from = module.nfw.module.central_inspection_with_egress_routing[0].aws_route.route_public_to_firewall_endpoint[0]
  to   = module.nfw_routes.aws_route.this["public-a-spoke-0"]
}
moved {
  from = module.nfw.module.central_inspection_with_egress_routing[0].aws_route.route_public_to_firewall_endpoint[1]
  to   = module.nfw_routes.aws_route.this["public-a-spoke-1"]
}
moved {
  from = module.nfw.module.central_inspection_with_egress_routing[1].aws_route.route_public_to_firewall_endpoint[0]
  to   = module.nfw_routes.aws_route.this["public-b-spoke-0"]
}
moved {
  from = module.nfw.module.central_inspection_with_egress_routing[1].aws_route.route_public_to_firewall_endpoint[1]
  to   = module.nfw_routes.aws_route.this["public-b-spoke-1"]
}
