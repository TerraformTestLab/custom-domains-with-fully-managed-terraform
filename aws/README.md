# Terraform — Fully Managed (AWS)

## Premise

This configuration provisions the **entire stack** for putting a custom domain in
front of an HCP Vault cluster on AWS, with nothing done by hand:

- the Vault cluster itself — created, or an existing one adopted read-only;
- the Route53 custom-domain record (`vault.<zone>`) and the matching
  `_acme-challenge` CNAME that Let's Encrypt validates;
- the HCP HVN ⇄ AWS VPC peering and the route tables on both sides — or an
  adoption of a peering established outside this config;
- an AWS Client VPN (with self-signed mTLS certificates) so a workstation can
  reach a private cluster: `laptop → Client VPN → VPC → peering → HVN`;
- optional Vault audit-log streaming to CloudWatch or an external SIEM.

Networking is never automatic. `public_link` decides whether a Client VPN or an
HVN peering can exist at all; on a private cluster `enable_vpn` and
`create_hvn_peering` are separate, explicit opt-ins. These four booleans have no
default — the plan errors until each one that applies is set. A public cluster
gets no VPN or peering, whatever the other values say.

**Use case:** stand up a demo or a production cluster whose API is served on your
own domain, from a clean slate, with one `terraform apply`.

**Scope:** the Terraform in this config takes you to the point where everything is
provisioned and the domain is *ready to be enabled*. Enabling the custom domain on
the cluster — the single HCP API call that makes HCP request the certificate — is
outside the Terraform, but it is walked through step by step in
[Enable-Custom-Domains.md](docs/Enable-Custom-Domains.md), with verification in
[Test-Custom-Domains.md](docs/Test-Custom-Domains.md) and teardown in
[Cleanup.md](docs/Cleanup.md).

## Prerequisites

`terraform >= 1.15.4` plus `AWS` and `HCP` credentials, and a set of resource
dependencies (HCP project, HVN, public Route53 zone, VPC, private subnet,
HVN ⇄ VPC peering, audit-log destination) — each of which this config can either
create or take as an existing resource you supply.

See [Prerequisites.md](docs/Prerequisites.md) for the full list.

## Modules

Six modules composed by the root configuration:

- `vault-cluster`
- `vault-custom-domain-records`
- `vault-hvn-peering`
- `vault-aws-client-vpn`
- `cloudwatch-audit-log`
- `vault-audit-log`

See [Modules.md](docs/Modules.md) for what each one does.

## Inputs

| Variable                       | Default                 | Purpose                                                                                                                                                                                |
|--------------------------------|-------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `aws_region`                   | `""`                    | AWS region for every regional resource (ACM, Client VPN, peering, routes). Must equal the HVN / VPC / subnet region                                                                    |
| `hcp_project_id`               | `""`                    | HCP project that owns the HVN and Vault cluster                                                                                                                                        |
| `route53_hosted_zone_name`     | `""`                    | Existing public Route53 hosted zone the Vault record is created in                                                                                                                     |
| `vault_record_name`            | `""`                    | Left-most label of the custom domain — must be `vault` (the domain is always `vault.<zone>`); empty or any other value fails validation                                                |
| `cluster_id`                   | `""`                    | ID of the Vault cluster this config manages — created when `create_cluster`, adopted read-only otherwise                                                                               |
| `create_cluster`               | `false`                 | `true` creates the cluster; `false` adopts an existing one with `cluster_id`                                                                                                           |
| `public_link`                  | **required**            | `true` → public endpoint, **no** VPN or peering ever created (networking vars ignored); `false` → private endpoint, `enable_vpn` and `create_hvn_peering` must then be set. No default |
| `vault_tier`                   | `""`                    | HCP Vault tier. Required when `create_cluster = true`; must be `""` when adopting                                                                                                      |
| `min_vault_version`            | `null`                  | Minimum Vault version (`vX.Y.Z`); `null` selects latest. Applied only when creating                                                                                                    |
| `audit_log_enabled`            | `false`                 | Master switch for Vault audit-log streaming                                                                                                                                            |
| `cloudwatch_audit_log_enabled` | `false`                 | When audit is on, have Terraform create + manage the CloudWatch destination instead of pointing at an external sink                                                                    |
| `vpc_id`                       | `""`                    | AWS VPC peered to the HVN and hosting the Client VPN. Required when the VPN or peering is active                                                                                       |
| `subnet_id`                    | `""`                    | Private subnet inside `vpc_id` for the VPN association / HVN route table. Required when the VPN or peering is active                                                                   |
| `client_vpn_cidr`              | `""`                    | Non-overlapping IPv4 CIDR (`/22` or larger) for VPN clients. Required when the Client VPN is active                                                                                    |
| `enable_vpn`                   | **required if private** | `true` → create the Client VPN; `false` → skip it (warning: assume external connectivity). Ignored when `public_link = true`. No default                                               |
| `hvn_id`                       | `""`                    | ID of the existing HCP HVN that hosts the cluster and peers with the VPC. Read-only, never created                                                                                     |
| `create_hvn_peering`           | **required if private** | `true` → create a new peering; `false` → adopt `existing_hvn_peering_id`, or (if `""`) manage no peering. Ignored when `public_link = true`. No default                                |
| `existing_hvn_peering_id`      | `""`                    | HCP-side slug of a peering established **outside** this config — adopted read-only, never managed here. Must be `""` when `create_hvn_peering = true`                                  |
| `manage_peering_routes`        | **required if peering** | `true` → manage both route directions; `false` → manage neither (warning). Independent of `create_hvn_peering`. Required only when a peering is created/adopted                        |
| `hvn_route_table_ids`          | `[]`                    | Explicit route tables to carry the HVN route. `[]` → the route table associated with `subnet_id`                                                                                       |

The table keeps only the two audit-log switches. The remaining audit-log inputs —
external SIEM sinks, managed-CloudWatch tuning, and the sink count — are in
[Audit-log inputs](docs/Inputs.md#audit-log-inputs).

For more in-depth details on each input, see [Inputs.md](docs/Inputs.md).

## Deploy

**NOTE:** You must configure your shell environment (HCP auth, AWS credentials) — see
[Prepare-Environment.md](docs/Prepare-Environment.md) before executing the commands listed bellow.

```shell
cd terraform-fully-managed/aws

terraform init      # local state in ./terraform.tfstate unless backend.tf's cloud block is enabled
terraform plan      # per-variable validation, plan-time cloud checks, cross-variable preconditions
terraform apply
```

With `terraform plan`/`apply`, an invalid or incomplete input set aborts before
any resource is touched — nothing downstream runs if validation, the plan-time
data checks, or the preflight preconditions fail.

Extract the Client VPN profile (only when the VPN is enabled):

```shell
terraform output -raw ovpn_file_content > vault-client-vpn.ovpn
chmod 600 vault-client-vpn.ovpn
```

Sanity-check the result:

```shell
terraform output vpn_enabled                # true/false for a private cluster based network configuration
terraform output vault_cname_fqdn           # vault.<zone>
terraform output vault_challenge_cname_fqdn # _acme-challenge.vault.<zone>
terraform output vault_target_hostname      # bare host the CNAME points at
```

At this point the cluster, DNS records, peering, routes, and Client VPN are all
in place — the custom domain is **ready to be enabled**. Enabling it (a single
HCP API call) and the certificate issuance it triggers are outside this config.
Continue in order:

1. **[validate-custom-domain-setup-with-hvn-peering-and-vpn-only.md](docs/validate-custom-domain-setup-with-hvn-peering-and-vpn-only.md)**
   — pre-flight checklist (one section for public clusters, one for private-only
   clusters reached over HVN peering and the Client VPN).
2. **[Enable-Custom-Domains.md](docs/Enable-Custom-Domains.md)** — set up the
   shell, fire the enable API, record the response, wait for the workflow.
3. **[Test-Custom-Domains.md](docs/Test-Custom-Domains.md)** — verify the domain
   resolves and answers over the VPN with a valid Let's Encrypt certificate.

## Teardown

[Cleanup.md](docs/Cleanup.md) reverses everything to state zero — disconnect the
VPN, `terraform destroy`, and (only if you adopted rather than created them)
remove the peering and cluster by hand. Note there is no supported call to turn
the custom domain off; destroying the DNS records is what stops it resolving.

## Outputs

Full list in `outputs.tf`; the ones you will usually read:

| Output                                                                | Meaning                                                                                             |
|-----------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------|
| `vault_cluster_id` / `vault_version` / `vault_cluster_tier`           | The cluster's ID, running version, and tier                                                         |
| `vault_cluster_created`                                               | `true` if this config created the cluster, `false` if it adopted one                                |
| `vault_private_endpoint_url` / `vault_public_endpoint_url`            | Cluster endpoints (`vault_public_endpoint_url` is empty when `public_link = false`)                 |
| `vault_target_hostname`                                               | Bare host the custom-domain CNAME points at (public host when `public_link`, else private)          |
| `vault_cname_fqdn`                                                    | FQDN of the Vault CNAME record (`vault.<zone>`)                                                     |
| `vault_challenge_cname_fqdn`                                          | FQDN of the `_acme-challenge` CNAME — the record Let's Encrypt's DNS-01 validation reads            |
| `is_private_endpoint` / `is_public_endpoint`                          | Which endpoint the domain targets (from `public_link`)                                              |
| `hvn_cidr` / `vpc_cidr`                                               | CIDRs read from the real HVN / VPC (never inputs; `vpc_cidr` empty when `vpc_id` unset)             |
| `audit_log_enabled` / `audit_log_destination`                         | Audit streaming state + active sink (`cloudwatch` / vendor name / `""`)                             |
| `audit_log_cloudwatch_group_name` / `audit_log_cloudwatch_iam_user`   | Managed CloudWatch audit resources (`null` unless that path is on)                                  |
| `hvn_peering_enabled` / `hvn_peering_created` / `hvn_peering_adopted` | Whether Terraform manages a peering, and whether it created it or adopted an externally-managed one |
| `hcp_peering_id` / `aws_peering_connection_id`                        | HCP-side peering slug and AWS-side `pcx-` connection ID                                             |
| `hvn_peering_state`                                                   | HCP peering state (expect `ACTIVE`)                                                                 |
| `hvn_peering_hvn_route_ids` / `hvn_peering_aws_route_table_ids`       | Routes / route tables that received the peering routes                                              |
| `vpn_enabled` / `vpn_endpoint_id` / `vpn_endpoint_dns_name`           | Client VPN state and endpoint                                                                       |
| `ovpn_file_path` / `ovpn_file_content` / `usage_instructions`         | Generated Client VPN profile — path, raw content, and connect instructions                          |

## Optional reading

Background material, not needed to run the config:

- **Module wiring diagram** — how the modules connect: a Mermaid chart, its
  legend, and a text table of the same wiring.
- **Audit logging configuration** — the full audit-log control model: switch
  matrix, what each module builds, the design rationale, on/off behavior,
  external-sink fields, and the security note.

See [Optional-Reading.md](docs/Optional-Reading.md).
