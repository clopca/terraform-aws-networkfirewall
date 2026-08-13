# Zonal traffic flow

AWS Network Firewall endpoints are zonal. A route table must select the endpoint
for its own Availability Zone, and the return path must preserve symmetry.

```mermaid
flowchart LR
  ClientA[Workload A] -->|forward: 0.0.0.0/0| AppRTA[Application RT A]
  AppRTA --> EPA[vpce firewall A]
  EPA --> NFW[AWS Network Firewall]
  NFW --> FwRTA[Firewall RT A]
  FwRTA --> NATA[NAT Gateway A]
  NATA --> IGW[Internet Gateway]
  IGW -->|return| NATA
  NATA --> NatRTA[NAT subnet RT A]
  NatRTA --> EPA
  EPA --> NFW
  NFW -->|application CIDR| ClientA
```

```mermaid
sequenceDiagram
  participant W as Workload in AZ A
  participant E as NFW endpoint A
  participant F as Network Firewall
  participant N as NAT Gateway A
  participant I as Internet
  W->>E: Forward packet
  E->>F: Inspect
  F->>N: Allowed packet
  N->>I: Source-NAT and send
  I-->>N: Response
  N-->>E: Return route to endpoint A
  E-->>F: Inspect reverse flow
  F-->>W: Route to workload CIDR
```

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
