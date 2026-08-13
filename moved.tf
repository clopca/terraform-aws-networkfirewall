moved {
  from = aws_networkfirewall_firewall.anfw
  to   = aws_networkfirewall_firewall.this["primary"]
}
