# Prerequisites

[← Back to README](../README.md)

This document lists what you must have in place before starting the guide.

## Accounts and access

You must have your own AWS sandbox account to complete this guide. Request one
from **Doormat → Accounts → AWS → Individual Sandbox Account**.

On the HCP side, you need membership of the organization and project that own the
HVN and the Vault cluster that will receive the custom domain.

You also need an HCP service principal with **Contributor** on the Vault service
in that project. This configuration uses the `hcp` Terraform provider to
provision (and read) the Vault cluster, and the provider authenticates with the
service principal's `HCP_CLIENT_ID` and `HCP_CLIENT_SECRET` rather than your user
login — `terraform init`, `plan`, and `apply` all fail without them. Create one
under HCP Portal → **Access control (IAM)** → **Service principals**, grant it
**Contributor** on Vault, and generate a key. See
[Prepare-Environment.md](Prepare-Environment.md) for where the credentials go.

### LaunchDarkly flags

The custom-domain feature is gated per project. Add your project to both flags
below.

| Flag                                                                                                                                                                                              | What it does                                                                                            |
|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------|
| [`hcpv-custom-domain-enabled`](https://app.launchdarkly.com/projects/cloud-services/flags/hcpv-custom-domain-enabled/targeting?env=dev&env=production&env=int&selected-env=dev)                   | Turns the custom-domain feature on for the project. The enable API is rejected without it.              |
| [`hcpv-custom-domain-throttle-enabled`](https://app.launchdarkly.com/projects/cloud-services/flags/hcpv-custom-domain-throttle-enabled/targeting?env=dev&env=production&env=int&selected-env=dev) | Defaults to `true`. Set it to `false` for your project to retry without exponential-backoff throttling. |

## Tools

- `terraform` 1.15.4 or newer
- `aws` CLI v2
- `hcp` CLI
- `vault` CLI
- `jq`, `dig`, `nc`, and `openssl`
- a VPN client for private clusters: Tunnelblick, OpenVPN Connect, or the AWS VPN Client

Verify they are all installed:

```shell
for t in terraform aws hcp vault jq dig nc openssl; do
  printf '%-10s ' "$t"; command -v "$t" || echo MISSING
done
```

## Resource dependencies

The configuration works with a fixed set of resources: an HCP project and HVN, a
Route 53 hosted zone, a Vault cluster, an AWS VPC and subnet, an HVN peering with
its routes, and an audit-log destination. Each one is either supplied by you as
an existing resource or created by Terraform. The three tables below group the
`terraform.tfvars` variables by which case applies.

### Supplied by you

This configuration never creates any of these. `aws_region`, `hcp_project_id`,
`hvn_id`, and `route53_hosted_zone_name` are required for every deployment. The
rest are conditional and are left `""` otherwise.

| Variable | What it identifies | Required | Where to find it |
|---|---|---|---|
| `aws_region` | The region that hosts the HVN, VPC, subnet, and cluster | Always | AWS Console, region menu at the top right; the code (for example `us-west-2`) also appears as the `?region=` value in the page URL |
| `hcp_project_id` | The HCP project that owns the HVN and the cluster | Always | HCP Portal → project picker in the top bar → **Project settings**; the value is also the `project_id=` segment of the URL |
| `hvn_id` | The HCP HVN the cluster runs in | Always | HCP Portal → **HashiCorp Virtual Networks** → your HVN → **Network ID** on the Overview tab |
| `route53_hosted_zone_name` | The public Route 53 hosted zone that holds the DNS records | Always | AWS Console → **Route 53** → **Hosted zones** → your public zone → its **Domain name**, without the trailing dot |
| `hcp_organization_id` | The HCP organization that owns the HVN and the cluster | When `manage_peering_routes = true` — `terraform plan` reads the HVN's existing routes from the HCP API to adopt them instead of duplicating them | HCP Portal → top-right org menu → **Settings** → **Organization ID**; also the `organization_id=` segment of the URL |
| `vpc_id` | The AWS VPC peered to the HVN and hosting the Client VPN | When `public_link = false` and `enable_vpn = true` or a peering is active | AWS Console → **VPC** → **Your VPCs** → the **VPC ID** column (`vpc-…`) |
| `subnet_id` | A private subnet inside `vpc_id` | Alongside `vpc_id`; must belong to it | AWS Console → **VPC** → **Subnets** → a private subnet in that VPC → its **Subnet ID** (`subnet-…`) |

When `manage_peering_routes = true`, that same plan-time read also needs a
current `HCP_API_TOKEN` and `HCP_API_ADDRESS` in your shell — the root
configuration reads both from the environment and injects them into the peering
module. See [Prepare-Environment.md](Prepare-Environment.md).

The HVN, VPC, subnet, and cluster must all be in the same region; `terraform
plan` fails when the HVN's region does not match `aws_region`. The HVN's region
and CIDR, and the VPC's CIDR, are read from the cloud rather than entered here.

### Optionally created and managed by Terraform

Set these when you want Terraform to provision the resource and own its lifecycle.
None of them is a portal lookup.

| Variable                       | Set it to | What Terraform then creates                                                                                                                                                                                                                       |
|--------------------------------|-----------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `create_cluster`               | `true`    | The HCP Vault cluster. `vault_tier` becomes required, `cluster_id` is the name you give the new cluster, and `min_vault_version` is optional                                                                                                      |
| `create_hvn_peering`           | `true`    | The HVN ⇄ VPC peering connection and its AWS-side accepter. `existing_hvn_peering_id` must stay empty                                                                                                                                             |
| `manage_peering_routes`        | `true`    | The route to the HVN CIDR on the AWS side and the route to the VPC CIDR on the HVN side, whether the peering was created or adopted                                                                                                               |
| `enable_vpn`                   | `true`    | The AWS Client VPN endpoint, its mTLS certificates, and the `.ovpn` profile. Needs `vpc_id` and `subnet_id` (first table), plus a `client_vpn_cidr` you choose: a private IPv4 block of `/22` or larger that does not overlap the VPC or HVN CIDR |
| `cloudwatch_audit_log_enabled` | `true`    | A CloudWatch log group and a dedicated IAM user for audit-log streaming. Requires `audit_log_enabled = true`                                                                                                                                      |

### Optionally folded in as an existing resource

Set these to point the configuration at a resource that already exists instead of
letting Terraform create one. Terraform reads these resources and routes through
them; it does not create or delete them.

| Variable                                                     | Existing resource it adopts                                      | Constraint                                                                                                                                            | Where to find it                                                                                                                |
|--------------------------------------------------------------|------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------|
| `cluster_id`, with `create_cluster = false`                  | The HCP Vault cluster, read-only                                 | `vault_tier` must be `""` and `min_vault_version` unset                                                                                               | HCP Portal → **Vault** → the cluster → **Cluster ID** on the Overview tab, also the last segment of the cluster URL             |
| `existing_hvn_peering_id`, with `create_hvn_peering = false` | An HVN ⇄ VPC peering established outside this configuration      | Mutually exclusive with `create_hvn_peering = true`; leaving it `""` as well means no peering is managed and connectivity is assumed to exist already | HCP Portal → **HashiCorp Virtual Networks** → your HVN → **Peerings** tab → the **Peering ID** column                           |
| `hvn_route_table_ids`                                        | Specific AWS route tables that should carry the route to the HVN | Consulted only when `manage_peering_routes = true`; `[]` uses the route table associated with `subnet_id`                                             | AWS Console → **VPC** → **Route tables** → the **Route table ID** column (`rtb-…`) for the tables serving your workload subnets |
| One `audit_log_<vendor>` object                              | Your existing external log or SIEM endpoint                      | Only with `audit_log_enabled = true` and `cloudwatch_audit_log_enabled = false`; exactly one may be set                                               | Your vendor's console — the API key, endpoint URL, or token it issues                                                           |

## Configure credentials

You need AWS sandbox credentials and the HCP service principal's `HCP_CLIENT_ID` /
`HCP_CLIENT_SECRET` in your shell for every Terraform command. With HCP Terraform
remote execution the same credentials must also exist as workspace variables (or
on a variable set applied to the workspace). See
[Prepare-Environment.md](Prepare-Environment.md) to configure both before you run
any Terraform command or call the custom-domain API.
