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
    IN_AUD["audit_log_enabled (master), audit_log_sink_count<br/>cloudwatch_audit_log_enabled, _group_name, _retention_days<br/>audit_log_datadog / splunk / elasticsearch / grafana / newrelic / http / cloudwatch"]
    IN_N["vpc_id, subnet_id, client_vpn_cidr, enable_vpn *"]
    IN_P["create_hvn_peering *, existing_hvn_peering_id<br/>manage_peering_routes *, hvn_route_table_ids"]
  end

  CHK{{"plan-time data checks<br/>hcp_hvn.check: exists + region == aws_region<br/>aws_vpc.check / aws_subnet.check: exist, subnet in vpc<br/>-> derives hvn_cidr, vpc_cidr from the real cloud"}}
  PRE{{"terraform_data.root_preflight — required-var guards<br/>public_link / enable_vpn / create_hvn_peering / manage_peering_routes<br/>terraform_data.audit_preflight — one destination, no clash"}}
  GATE{{"root locals<br/>enable_vpn = private AND enable_vpn<br/>manage_peering = private AND (create_hvn_peering OR existing_hvn_peering_id)"}}
  AMERGE{{"root local: audit_log_config<br/>managed CloudWatch, else external sink, else []"}}

  MCW["cloudwatch-audit-log — OPTIONAL<br/>count = audit_log_enabled AND cloudwatch_audit_log_enabled<br/>creates: log group + IAM user + access key + policy<br/>in *: cluster_id, aws_region"]
  MA["vault-audit-log — OPTIONAL<br/>active when audit_log_enabled AND NOT cloudwatch_audit_log_enabled<br/>external sink, config builder, no resources"]
  MC["vault-cluster — MANDATORY<br/>create_cluster ? hcp_vault_cluster : data.hcp_vault_cluster<br/>in *: cluster_id, hvn_id"]
  MR["vault-custom-domain-records — MANDATORY<br/>Route53 CNAME plus acme-challenge CNAME<br/>in *: route53_hosted_zone_name, vault_record_name, vault_target_hostname"]
  MP["vault-hvn-peering — OPTIONAL<br/>count = manage_peering ? 1 : 0 (private AND create-or-adopt)<br/>self-validates: vpc/subnet present, create XOR adopt, VPC/HVN non-overlap<br/>in *: hvn_id, vpc_id, subnet_id, peer_vpc_region"]
  MV["vault-aws-client-vpn — OPTIONAL<br/>count = enable_vpn ? 1 : 0 (private AND opted in)<br/>self-validates: vpc/subnet/client_cidr present, client/VPC/HVN non-overlap<br/>in *: vpc_id, subnet_id, vpc_cidr, hvn_cidr, client_vpn_cidr"]

  OC["outputs: vault_cluster_id, vault_cluster_created, vault_cluster_tier, vault_version<br/>vault_private_endpoint_url, vault_public_endpoint_url, vault_target_hostname"]
  OA["outputs: audit_log_enabled, audit_log_destination<br/>audit_log_cloudwatch_group_name, audit_log_cloudwatch_iam_user"]
  OR["outputs: vault_cname_fqdn, vault_challenge_cname_fqdn"]
  OG["outputs: is_private_endpoint, is_public_endpoint, hvn_cidr, vpc_cidr"]
  OP["outputs: hvn_peering_enabled, hvn_peering_created, hcp_peering_id<br/>aws_peering_connection_id, hvn_peering_state<br/>hvn_peering_hvn_route_ids, hvn_peering_aws_route_table_ids"]
  OV["outputs: vpn_enabled, vpn_endpoint_id, vpn_endpoint_dns_name<br/>ovpn_file_path, ovpn_file_content, usage_instructions"]

  class MC,MR mand
  class MCW,MA,MP,MV opt
  class OC,OA,OR,OG,OP,OV io
  class GATE,AMERGE gate
  class CHK,PRE guard

  IN_G --> CHK
  IN_C -->|hvn_id| CHK
  IN_N -->|vpc_id, subnet_id| CHK

  IN_AUD --> MCW
  IN_AUD --> MA
  IN_C -->|cluster_id| MCW
  IN_G -->|aws_region| MCW
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

  IN_AUD --> PRE
  IN_C --> PRE
  IN_N --> PRE
  IN_P --> PRE
  CHK -->|hvn_cidr, vpc_cidr| MV
  GATE --> PRE

  MCW -->|config| AMERGE
  MA -->|config| AMERGE
  AMERGE -->|audit_log_config| MC
  MC -->|vault_target_hostname| MR
  GATE -.->|enables count| MP
  GATE -.->|enables count| MV
  MR -->|"vault_cname_fqdn -> vault_fqdn"| MV
  MP -.->|depends_on| MV

  MC --> OC
  MCW --> OA
  MA --> OA
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
| Purple hexagon | Not a module — a `main.tf` local. `GATE` derives `enable_vpn` and `manage_peering` from `public_link` and the opt-ins; `AMERGE` picks which audit configuration reaches the cluster. |
| Red hexagon | Validation. `CHK` reads the HVN, VPC, and subnet at plan time and derives their CIDRs; `PRE` is the required-variable and audit-destination guards. Either one aborts the plan on failure. |
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

The full input-to-outcome matrix is in
[Networking enablement](Inputs.md#networking-enablement).

## Audit logging configuration

Two switches in `terraform.tfvars`. `audit_log_enabled` turns audit logging on or
off. `cloudwatch_audit_log_enabled` then chooses how the destination is provided:
Terraform creates a CloudWatch group, or you point at a sink that already exists.

| `audit_log_enabled` | `cloudwatch_audit_log_enabled` | `audit_log_<vendor>` objects | Result |
|:---:|:---:|:---:|---|
| `false` | any | any | No audit logging; everything else is ignored |
| `true` | `true` | none | Terraform creates the CloudWatch log group and IAM user and streams to it |
| `true` | `true` | one or more | Plan fails — that path owns its destination; remove the vendor object |
| `true` | `false` | exactly one | Terraform forwards your credentials to that existing sink |
| `true` | `false` | none, or more than one | Plan fails — the destination is missing or ambiguous |
| `false` | `true` | any | Plan fails — `cloudwatch_audit_log_enabled` needs the master switch |
| any, with `create_cluster = false` | — | any set | Plan fails — audit configuration cannot be pushed to an adopted cluster |

### What each module builds

- **`cloudwatch-audit-log`** creates a log group (`/hcp/vault/<cluster_id>/audit`
  by default), a dedicated IAM user with a one-log-group policy, and an access
  key. Its output is the `audit_log_config` payload HCP needs.
- **`vault-audit-log`** creates nothing; it packages the credentials you supply
  for one of the seven external sinks.
- **`vault-cluster`** splices whichever payload is active into the cluster's
  `audit_log_config` block.

### Design notes

- CloudWatch is the managed path because it is the only sink Terraform can build
  end to end with the `aws` provider already in use. The other six need an
  external account and an API token.
- HCP's CloudWatch integration accepts only a static access key, so the managed
  path issues one; the blast radius is a dedicated user scoped to a single log
  group.
- Two switches rather than one: whether audit logging is on is separate from who
  owns the destination. A missing or ambiguous destination is a hard error, not
  a silent skip, because audit logging that quietly does not happen is a
  compliance risk.
- `audit_log_sink_count` (default `1`) names the "exactly one external sink" rule
  so it is visible and easy to widen if HCP ever allows more.

### Turning it on or off

Enabling audit logging on an existing cluster is an in-place update; the cluster
is not rebuilt. Disabling it removes the block, and if the CloudWatch path was
active its resources are destroyed. Audit configuration applies only to a cluster
this configuration creates.

### External sink fields

Set `audit_log_enabled = true`, `cloudwatch_audit_log_enabled = false`, and
exactly one object below. Keep secrets out of version control — use
`TF_VAR_audit_log_<vendor>` or a git-ignored `*.auto.tfvars`.

| Sink            | Required fields                       | Optional fields                                                                                                                 |
|-----------------|---------------------------------------|---------------------------------------------------------------------------------------------------------------------------------|
| `cloudwatch`    | `region`, `group_name`                | `stream_name`, `access_key_id`, `secret_access_key`                                                                             |
| `datadog`       | `api_key`, `region`                   | —                                                                                                                               |
| `elasticsearch` | `endpoint`, `user`, `password`        | `dataset`                                                                                                                       |
| `grafana`       | `endpoint`, `user`, `password`        | —                                                                                                                               |
| `splunk`        | `hec_endpoint`, `token`               | —                                                                                                                               |
| `newrelic`      | `account_id`, `license_key`, `region` | —                                                                                                                               |
| `http`          | `uri`                                 | `method`, `codec`, `compression`, `headers`, `basic_user`, `basic_password`, `bearer_token`, `payload_prefix`, `payload_suffix` |

### Security note

The managed CloudWatch path writes an IAM secret access key into Terraform state
and sends it to HCP; this is intrinsic to HCP's integration. The key belongs to a
dedicated user with a one-log-group policy, and rotating it is a single
`terraform apply -replace=…`. Protect state accordingly: with the local backend,
keep `terraform.tfstate` out of version control and off shared disks; HCP
Terraform stores it encrypted. External sinks carry the same caveat for whatever
token you pass them.
