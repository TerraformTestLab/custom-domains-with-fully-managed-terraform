# Outputs

[← Back to README](../README.md)

Read any of these with `terraform output <name>` after `terraform apply`. The
full definitions are in `outputs.tf`.

## Cluster

| Output                       | Type   | Description                                                                    |
|------------------------------|--------|--------------------------------------------------------------------------------|
| `vault_cluster_id`           | string | ID of the HCP Vault cluster                                                    |
| `vault_cluster_created`      | bool   | `true` if Terraform created the cluster, `false` if it adopted an existing one |
| `vault_cluster_tier`         | string | Tier of the cluster                                                            |
| `vault_version`              | string | Running Vault version                                                          |
| `vault_private_endpoint_url` | string | Private endpoint URL                                                           |
| `vault_public_endpoint_url`  | string | Public endpoint URL; empty when `public_link = false`                          |
| `is_private_endpoint`        | bool   | The custom domain targets the private endpoint (`public_link = false`)         |
| `is_public_endpoint`         | bool   | The custom domain targets the public endpoint (`public_link = true`)           |

## Custom domain

| Output                       | Type   | Description                                                                                           |
|------------------------------|--------|-------------------------------------------------------------------------------------------------------|
| `vault_cname_fqdn`           | string | FQDN of the Vault CNAME record (`vault.<zone>`)                                                       |
| `vault_challenge_cname_fqdn` | string | FQDN of the `_acme-challenge` CNAME that Let's Encrypt's DNS-01 check reads                           |
| `vault_target_hostname`      | string | Bare host the CNAME points at — the public host when `public_link = true`, the private host otherwise |

## HVN peering and network facts

| Output                            | Type                | Description                                                                                                                          |
|-----------------------------------|---------------------|--------------------------------------------------------------------------------------------------------------------------------------|
| `hvn_cidr`                        | string              | IPv4 CIDR of the HVN, read from HCP                                                                                                  |
| `vpc_cidr`                        | string              | Primary IPv4 CIDR of the VPC, read from AWS; empty when `vpc_id` is unset                                                            |
| `hvn_peering_enabled`             | bool                | Terraform manages a peering (created or adopted); `false` for a public cluster or a private cluster relying on external connectivity |
| `hvn_peering_created`             | bool / null         | Terraform created the peering; `null` when no peering is managed                                                                     |
| `hvn_peering_adopted`             | bool / null         | Terraform adopted a peering established outside this configuration; `null` when no peering is managed                                |
| `hvn_peering_state`               | string / null       | Current HCP peering state (expect `ACTIVE`)                                                                                          |
| `hcp_peering_id`                  | string / null       | Slug ID of the HCP network peering                                                                                                   |
| `aws_peering_connection_id`       | string / null       | AWS-side peering connection ID (`pcx-…`)                                                                                             |
| `hvn_peering_hvn_route_ids`       | list(string) / null | HVN routes pointing back at the VPC CIDR(s)                                                                                          |
| `hvn_peering_aws_route_table_ids` | list(string) / null | AWS route tables that received a route to the HVN CIDR                                                                               |

## Client VPN

All `null` unless `enable_vpn = true`.

| Output                  | Type          | Description                                       |
|-------------------------|---------------|---------------------------------------------------|
| `vpn_enabled`           | bool          | The Client VPN module is active                   |
| `vpn_endpoint_id`       | string / null | ID of the AWS Client VPN endpoint                 |
| `vpn_endpoint_dns_name` | string / null | DNS name of the Client VPN endpoint               |
| `ovpn_file_path`        | string / null | Path of the generated `.ovpn` profile             |
| `ovpn_file_content`     | string / null | Raw contents of the `.ovpn` profile (sensitive)   |
| `usage_instructions`    | string / null | How to save the profile, connect, and reach Vault |

## Audit logging

| Output                            | Type          | Description                                                                                |
|-----------------------------------|---------------|--------------------------------------------------------------------------------------------|
| `audit_log_enabled`               | bool          | Any audit-log streaming is active                                                          |
| `audit_log_destination`           | string        | Active sink: `cloudwatch`, the external vendor name, or `""`                               |
| `audit_log_cloudwatch_group_name` | string / null | CloudWatch log group receiving the stream; `null` unless the managed-CloudWatch path is on |
| `audit_log_cloudwatch_iam_user`   | string / null | IAM user HCP uses to write to CloudWatch; `null` unless the managed-CloudWatch path is on  |
