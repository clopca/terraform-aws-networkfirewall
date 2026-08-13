moved {
  from = aws_route.tgw_to_firewall_endpoint[0]
  to   = aws_route.connectivity_to_firewall_endpoint[0]
}
moved {
  from = aws_route.connectivity_to_firewall_endpoint[0]
  to   = module.routes.aws_route.this["central-egress-0"]
}
moved {
  from = aws_route.tgw_to_firewall_endpoint[1]
  to   = aws_route.connectivity_to_firewall_endpoint[1]
}
moved {
  from = aws_route.connectivity_to_firewall_endpoint[1]
  to   = module.routes.aws_route.this["central-egress-1"]
}
moved {
  from = aws_route.tgw_to_firewall_endpoint[2]
  to   = aws_route.connectivity_to_firewall_endpoint[2]
}
moved {
  from = aws_route.connectivity_to_firewall_endpoint[2]
  to   = module.routes.aws_route.this["central-egress-2"]
}
moved {
  from = aws_route.tgw_to_firewall_endpoint[3]
  to   = aws_route.connectivity_to_firewall_endpoint[3]
}
moved {
  from = aws_route.connectivity_to_firewall_endpoint[3]
  to   = module.routes.aws_route.this["central-egress-3"]
}
moved {
  from = aws_route.tgw_to_firewall_endpoint[4]
  to   = aws_route.connectivity_to_firewall_endpoint[4]
}
moved {
  from = aws_route.connectivity_to_firewall_endpoint[4]
  to   = module.routes.aws_route.this["central-egress-4"]
}
moved {
  from = aws_route.tgw_to_firewall_endpoint[5]
  to   = aws_route.connectivity_to_firewall_endpoint[5]
}
moved {
  from = aws_route.connectivity_to_firewall_endpoint[5]
  to   = module.routes.aws_route.this["central-egress-5"]
}

moved {
  from = aws_route.tgw_to_firewall_endpoint_without_egress[0]
  to   = aws_route.connectivity_to_firewall_endpoint_without_egress[0]
}
moved {
  from = aws_route.connectivity_to_firewall_endpoint_without_egress[0]
  to   = module.routes.aws_route.this["central-without-egress-0"]
}
moved {
  from = aws_route.tgw_to_firewall_endpoint_without_egress[1]
  to   = aws_route.connectivity_to_firewall_endpoint_without_egress[1]
}
moved {
  from = aws_route.connectivity_to_firewall_endpoint_without_egress[1]
  to   = module.routes.aws_route.this["central-without-egress-1"]
}
moved {
  from = aws_route.tgw_to_firewall_endpoint_without_egress[2]
  to   = aws_route.connectivity_to_firewall_endpoint_without_egress[2]
}
moved {
  from = aws_route.connectivity_to_firewall_endpoint_without_egress[2]
  to   = module.routes.aws_route.this["central-without-egress-2"]
}
moved {
  from = aws_route.tgw_to_firewall_endpoint_without_egress[3]
  to   = aws_route.connectivity_to_firewall_endpoint_without_egress[3]
}
moved {
  from = aws_route.connectivity_to_firewall_endpoint_without_egress[3]
  to   = module.routes.aws_route.this["central-without-egress-3"]
}
moved {
  from = aws_route.tgw_to_firewall_endpoint_without_egress[4]
  to   = aws_route.connectivity_to_firewall_endpoint_without_egress[4]
}
moved {
  from = aws_route.connectivity_to_firewall_endpoint_without_egress[4]
  to   = module.routes.aws_route.this["central-without-egress-4"]
}
moved {
  from = aws_route.tgw_to_firewall_endpoint_without_egress[5]
  to   = aws_route.connectivity_to_firewall_endpoint_without_egress[5]
}
moved {
  from = aws_route.connectivity_to_firewall_endpoint_without_egress[5]
  to   = module.routes.aws_route.this["central-without-egress-5"]
}
