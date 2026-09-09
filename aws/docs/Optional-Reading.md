# Optional reading

[← Back to README](../README.md)

Background on how the pieces fit together. Not needed to run the configuration.

## Module wiring diagram

Which modules always run, which are conditional, and which output of one feeds
the input of the next.

```mermaid
flowchart TB
  classDef mand  fill:#dbeafe,stroke:#1d4ed8,stroke-width:2px,color:#0f172a
  classDef opt   fill:#fef9c3,stroke:#a16207,stroke-width:2px,stroke-dasharray:6 4,color:#0f172a
  classDef io    fill:#f1f5f9,stroke:#64748b,color:#0f172a
  classDef gate  fill:#ede9fe,stroke:#6d28d9,color:#0f172a
  classDef guard fill:#fee2e2,stroke:#b91c1c,stroke-width:2px,color:#0f172a

  subgraph IN["terraform.tfvars (validated per-variable)"]
    direction TB
    IN_G["aws_region *, hcp_project_id *"]
    IN_D["route53_hosted_zone_name *, vault_record_name *"]
    IN_C["cluster_id *, hvn_id *, create_cluster<br/>public_link *, vault_tier, min_vault_version"]
    IN_N["vpc_id, subnet_id, client_vpn_cidr, enable_vpn *"]
    IN_P["create_hvn_peering *, existing_hvn_peering_id<br/>manage_peering_routes *, hvn_route_table_ids"]
  end

  CHK{{"plan-time data checks<br/>hcp_hvn.check: exists + region == aws_region<br/>aws_vpc.check / aws_subnet.check: exist, subnet in vpc<br/>-> derives hvn_cidr, vpc_cidr from the real cloud"}}
  PRE{{"terraform_data.root_preflight — required-var guards<br/>public_link / enable_vpn / create_hvn_peering / manage_peering_routes"}}
  GATE{{"root locals<br/>enable_vpn = private AND enable_vpn<br/>manage_peering = private AND (create_hvn_peering OR existing_hvn_peering_id)"}}

  MC["vault-cluster — MANDATORY<br/>create_cluster ? hcp_vault_cluster : data.hcp_vault_cluster<br/>in *: cluster_id, hvn_id"]
  MR["vault-custom-domain-records — MANDATORY<br/>Route53 CNAME plus acme-challenge CNAME<br/>in *: route53_hosted_zone_name, vault_record_name, vault_target_hostname"]
  MP["vault-hvn-peering — OPTIONAL<br/>count = manage_peering ? 1 : 0 (private AND create-or-adopt)<br/>self-validates: vpc/subnet present, create XOR adopt, VPC/HVN non-overlap<br/>in *: hvn_id, vpc_id, subnet_id, peer_vpc_region"]
  MV["vault-aws-client-vpn — OPTIONAL<br/>count = enable_vpn ? 1 : 0 (private AND opted in)<br/>self-validates: vpc/subnet/client_cidr present, client/VPC/HVN non-overlap<br/>in *: vpc_id, subnet_id, vpc_cidr, hvn_cidr, client_vpn_cidr"]

  OC["outputs: vault_cluster_id, vault_cluster_created, vault_cluster_tier, vault_version<br/>vault_private_endpoint_url, vault_public_endpoint_url, vault_target_hostname"]
  OR["outputs: vault_cname_fqdn, vault_challenge_cname_fqdn"]
  OG["outputs: is_private_endpoint, is_public_endpoint, hvn_cidr, vpc_cidr"]
  OP["outputs: hvn_peering_enabled, hvn_peering_created, hcp_peering_id<br/>aws_peering_connection_id, hvn_peering_state<br/>hvn_peering_hvn_route_ids, hvn_peering_aws_route_table_ids"]
  OV["outputs: vpn_enabled, vpn_endpoint_id, vpn_endpoint_dns_name<br/>ovpn_file_path, ovpn_file_content, usage_instructions"]

  class MC,MR mand
  class MP,MV opt
  class OC,OR,OG,OP,OV io
  class GATE gate
  class CHK,PRE guard

  IN_G --> CHK
  IN_C -->|hvn_id| CHK
  IN_N -->|vpc_id, subnet_id| CHK

  IN_C --> MC
  IN_C --> GATE
  IN_N -.->|enable_vpn| GATE
  IN_P -.->|create / adopt flags| GATE
  IN_D --> MR
  IN_C -->|hvn_id| MP
  IN_G -->|"aws_region -> peer_vpc_region"| MP
  IN_N --> MP
  IN_P -.->|create / adopt / route flags| MP
  IN_N --> MV

  IN_C --> PRE
  IN_N --> PRE
  IN_P --> PRE
  CHK -->|hvn_cidr, vpc_cidr| MV
  GATE --> PRE

  MC -->|vault_target_hostname| MR
  GATE -.->|enables count| MP
  GATE -.->|enables count| MV
  MR -->|"vault_cname_fqdn -> vault_fqdn"| MV
  MP -.->|depends_on| MV

  MC --> OC
  MR --> OR
  GATE --> OG
  CHK --> OG
  MP -.-> OP
  MV -.-> OV
```

### Legend

| Element | Meaning |
|---|---|
| Blue node | A module that always runs |
| Yellow dashed node | A module that runs only when its condition is met |
| Purple hexagon | Not a module — a `main.tf` local. `GATE` derives `enable_vpn` and `manage_peering` from `public_link` and the opt-ins. |
| Red hexagon | Validation. `CHK` reads the HVN, VPC, and subnet at plan time and derives their CIDRs; `PRE` is the required-variable guards. Either one aborts the plan on failure. |
| Grey node | A group of `outputs.tf` values |
| Solid arrow | Wiring always in effect |
| Dashed arrow | Conditional wiring — a `count` toggle, `depends_on` ordering, or an override |
| `*` on an input | Must be set; the default fails validation |

Key points:

- `CHK` and `PRE` run during `plan`, and `apply` plans first, so an invalid
  input set never reaches resource creation.
- `hvn_cidr` and `vpc_cidr` are read from the cloud, not entered.
- `create_cluster = false`, and `create_hvn_peering = false` with
  `existing_hvn_peering_id` set, make `vault-cluster` and `vault-hvn-peering`
  read existing resources rather than create them.
- `GATE -.-> MP` / `GATE -.-> MV` is the `count` decision, not a value.
  `MP -.-> MV` is apply ordering, not data flow.
- With `manage_peering_routes = true`, `vault-hvn-peering` reads the HVN's
  existing routes from the HCP API at plan time (`data.http.hvn_routes`) and the
  target route tables from AWS. The API host and bearer token come from
  `HCP_API_ADDRESS` / `HCP_API_TOKEN`, which the root reads from the environment
  and passes in; the organization is `hcp_organization_id`. A route direction
  that already exists and points at this peering is adopted through a root
  `import` block instead of failing on a duplicate; one that points elsewhere
  fails the plan. A brand-new peering (`create_hvn_peering = true`) has nothing
  to adopt, so both directions are created.

The full input-to-outcome matrix is in
[Networking enablement](Inputs.md#networking-enablement).
