# Suricata rule group

Creates one STRICT_ORDER rule group from `egress.rules`, with environment bindings supplied through typed IP and port sets. The `manifest_uri` and digest represent an external CI artifact; replace both with evidence produced by the rule validation pipeline before apply. Do not derive the expected digest from the same local file inside this configuration.
