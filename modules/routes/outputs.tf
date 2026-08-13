output "route_ids" {
  description = "Route IDs by caller-controlled route key."
  value       = { for key, route in aws_route.this : key => route.id }
}

output "resources" {
  description = "Internal route resources. This shape is not semver-protected."
  value       = { routes = aws_route.this }
}
