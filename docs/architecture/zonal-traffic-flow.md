# Zonal traffic flow

AWS Network Firewall endpoints are zonal. A route table must select the endpoint
for its own Availability Zone, and the return path must preserve symmetry.

In Availability Zone A, the workload default route selects firewall endpoint A.
The endpoint sends the packet through AWS Network Firewall, and the firewall
subnet route sends an allowed packet to NAT Gateway A and then the Internet
Gateway. The response returns through NAT Gateway A, whose route for the
application CIDR selects firewall endpoint A; inspection completes before the
VPC local route returns the packet to the workload.





## Invariants

- Endpoint map keys equal the source route-table AZ set.
- Every source table uses its same-AZ endpoint.
- The route after inspection reaches the intended NAT, TGW, IGW path, or
  destination network.
- Return routes re-enter the same endpoint AZ before reaching the source CIDR.
- TGW centralized inspection uses appliance mode and deliberately designed TGW
  route-table associations/propagations.
- Endpoint readiness and logging health are verified before cutover.

Static Terraform validation cannot prove these invariants against live traffic.
Run per-AZ positive, negative, management-path, and return-path probes.
