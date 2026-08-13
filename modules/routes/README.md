# Routes bridge module

This transitional adapter creates only caller-keyed `aws_route` resources. It does not create, import, associate, or inspect route tables. Every route selects one Network Firewall endpoint through `endpoint_zone_key` and an IPv4 or IPv6 CIDR destination.

The typed contract retains `prefix_list_id`, but provider 6.59 declares it incompatible with `vpc_endpoint_id`; the module therefore fails closed with a correction to expand the list into caller-keyed CIDR routes. It never sends an invalid route to AWS.

The caller remains responsible for the complete inventory and ownership of external route tables. This bridge cannot prove that an unmanaged table has no conflicting route omitted from the declaration. New VPC-module integrations should prefer a native zonal endpoint target when available.
