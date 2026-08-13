moved {
  from = aws_networkfirewall_firewall.anfw
  to   = aws_networkfirewall_firewall.this["primary"]
}

moved {
  from = module.logging[0].aws_networkfirewall_logging_configuration.anfw_logs
  to   = module.logging.aws_networkfirewall_logging_configuration.this["primary"]
}

moved {
  from = aws_route.protected_route_table_to_internet[0]
  to   = module.routes.aws_route.this["public-a-default-v4"]
}
