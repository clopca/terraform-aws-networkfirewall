moved {
  from = module.firewalls.aws_networkfirewall_firewall.this["alpha"]
  to   = module.firewalls.aws_networkfirewall_firewall.this["renamed"]
}

moved {
  from = module.firewalls.terraform_data.firewall_contract["alpha"]
  to   = module.firewalls.terraform_data.firewall_contract["renamed"]
}

moved {
  from = module.logging.aws_networkfirewall_logging_configuration.this["alpha"]
  to   = module.logging.aws_networkfirewall_logging_configuration.this["renamed"]
}

moved {
  from = module.logging.terraform_data.logging_contract["alpha"]
  to   = module.logging.terraform_data.logging_contract["renamed"]
}

moved {
  from = module.routes.aws_route.this["alpha"]
  to   = module.routes.aws_route.this["renamed"]
}

moved {
  from = module.routes.terraform_data.route_contract["alpha"]
  to   = module.routes.terraform_data.route_contract["renamed"]
}
