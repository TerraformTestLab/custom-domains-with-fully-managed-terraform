# Inputs

[← Back to README](../README.md)

Set these in `terraform.tfvars`. String variables default to `""` and ship as
`REPLACE_WITH_*` placeholders; a placeholder or a missing required value fails
`terraform plan` with a message that names the variable. Where each value comes
from is in [Prerequisites.md](Prerequisites.md#resource-dependencies).

## Variables

| Variable                       | Default | Purpose                                                                                                                                               |
|--------------------------------|---------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| `aws_region`                   | `""`    | Region for every AWS resource. Must match the HVN, VPC, and subnet region.                                                                            |
| `hcp_project_id`               | `""`    | HCP project that owns the HVN and cluster.                                                                                                            |
| `route53_hosted_zone_name`     | `""`    | Existing public Route 53 zone the records are created in.                                                                                             |
| `vault_record_name`            | `""`    | Must be `vault`; the custom domain is always `vault.<zone>`.                                                                                          |
| `hvn_id`                       | `""`    | Existing HCP HVN. Read-only.                                                                                                                          |
| `cluster_id`                   | `""`    | The cluster to manage — a new name when `create_cluster = true`, an existing ID otherwise.                                                            |
| `create_cluster`               | `false` | `true` creates the cluster (needs `vault_tier`); `false` adopts `cluster_id` read-only.                                                               |
| `vault_tier`                   | `""`    | Cluster tier. Required when creating, `""` when adopting.                                                                                             |
| `min_vault_version`            | `null`  | Minimum Vault version when creating; `null` picks the latest.                                                                                         |
| `public_link`                  | —       | `true` for a public endpoint — no Client VPN or peering, ever. `false` for a private endpoint.                                                        |
| `enable_vpn`                   | —       | Private clusters only. `true` creates the Client VPN, `false` skips it.                                                                               |
| `create_hvn_peering`           | —       | Private clusters only. `true` creates the peering; `false` adopts `existing_hvn_peering_id`, or manages no peering if that is empty.                  |
| `existing_hvn_peering_id`      | `""`    | An HVN ⇄ VPC peering established outside this configuration, adopted read-only. Must be `""` when `create_hvn_peering = true`.                        |
| `manage_peering_routes`        | —       | Required once a peering is created or adopted. `true` writes both route directions, `false` writes neither.                                           |
| `hvn_route_table_ids`          | `[]`    | Route tables to carry the HVN route. `[]` uses the one associated with `subnet_id`. Applies only when `manage_peering_routes = true`.                 |
| `vpc_id`                       | `""`    | Existing VPC. Required when the Client VPN or a peering is active.                                                                                    |
| `subnet_id`                    | `""`    | Private subnet inside `vpc_id`. Required alongside `vpc_id`.                                                                                          |
| `client_vpn_cidr`              | `""`    | Address pool for VPN clients — a private block of `/22` or larger that does not overlap the VPC or HVN range. Required when the Client VPN is active. |
| `audit_log_enabled`            | `false` | Master switch for audit-log streaming. See [Audit-log inputs](#audit-log-inputs).                                                                     |
| `cloudwatch_audit_log_enabled` | `false` | With audit on: `true` has Terraform create the CloudWatch destination, `false` points at an external sink.                                            |

`public_link`, `enable_vpn`, `create_hvn_peering`, and `manage_peering_routes`
have no default. The plan fails until each one that applies is set; a public
cluster needs only `public_link`. See [Networking enablement](#networking-enablement).

## Audit-log inputs

Consulted only when `audit_log_enabled = true`.

- With `cloudwatch_audit_log_enabled = true`, Terraform creates the CloudWatch
  log group and IAM user; `cloudwatch_audit_log_group_name` and
  `cloudwatch_audit_log_retention_days` tune them.
- With `cloudwatch_audit_log_enabled = false`, set exactly one
  `audit_log_<vendor>` object for a sink that already exists.

| Variable                              | Default | Purpose                                                               |
|---------------------------------------|---------|-----------------------------------------------------------------------|
| `cloudwatch_audit_log_group_name`     | `""`    | Managed log group name. `""` derives `/hcp/vault/<cluster_id>/audit`. |
| `cloudwatch_audit_log_retention_days` | `30`    | Retention in days for the managed log group; `0` keeps forever.       |
| `audit_log_sink_count`                | `1`     | External sinks expected. HCP accepts one.                             |
| `audit_log_cloudwatch`                | `null`  | External sink — a CloudWatch group and IAM key you manage yourself.   |
| `audit_log_datadog`                   | `null`  | External sink — Datadog.                                              |
| `audit_log_elasticsearch`             | `null`  | External sink — Elasticsearch.                                        |
| `audit_log_grafana`                   | `null`  | External sink — Grafana Loki.                                         |
| `audit_log_splunk`                    | `null`  | External sink — Splunk HTTP Event Collector.                          |
| `audit_log_newrelic`                  | `null`  | External sink — New Relic.                                            |
| `audit_log_http`                      | `null`  | External sink — generic HTTP.                                         |

Audit configuration applies only to a cluster this configuration creates. The
full control model and the per-sink fields are in
[Optional-Reading.md](Optional-Reading.md#audit-logging-configuration).

## Validation

`terraform plan` rejects a value that does not match its rule.

| Variable                                                 | Accepted value                                                                                                       |
|----------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------|
| `aws_region`, `audit_log_cloudwatch.region`              | AWS region code, for example `us-west-2`                                                                             |
| `hcp_project_id`                                         | UUID                                                                                                                 |
| `route53_hosted_zone_name`                               | bare domain, no scheme or trailing dot                                                                               |
| `vault_record_name`                                      | exactly `vault`                                                                                                      |
| `cluster_id`, `hvn_id`, `existing_hvn_peering_id`        | HCP slug: 3–36 lowercase letters, digits, or hyphens                                                                 |
| `vault_tier`                                             | `""`, or one of `dev`, `starter_small`, `standard_small` / `_medium` / `_large`, `plus_small` / `_medium` / `_large` |
| `min_vault_version`                                      | `vX.Y.Z` or `null`                                                                                                   |
| `vpc_id` / `subnet_id` / `hvn_route_table_ids[*]`        | `""` or the matching `vpc-` / `subnet-` / `rtb-` ID                                                                  |
| `client_vpn_cidr`                                        | `""`, or an IPv4 CIDR of `/22` or larger                                                                             |
| `cloudwatch_audit_log_retention_days`                    | a retention value CloudWatch allows                                                                                  |
| `cloudwatch_audit_log_group_name`                        | `""`, or up to 512 characters from `[-A-Za-z0-9_./#]`                                                                |
| `audit_log_sink_count`                                   | `1`                                                                                                                  |
| `audit_log_datadog.region`                               | `us1` / `us3` / `us5` / `eu1` / `ap1` / `us1-fed`                                                                    |
| `audit_log_newrelic.region`                              | `US` / `EU`                                                                                                          |
| `audit_log_{elasticsearch,grafana,splunk,http}` endpoint | a URL                                                                                                                |
| `audit_log_http.method` / `.codec`                       | `POST` or `PUT` / `json` or `ndjson`                                                                                 |
| `audit_log_cloudwatch`                                   | `access_key_id` and `secret_access_key` set together, or neither                                                     |

Cross-field rules, also checked at plan time:

- `create_cluster = true` needs `vault_tier`. `create_cluster = false` needs
  `vault_tier = ""`, `min_vault_version = null`, and every audit input off.
- `create_hvn_peering = true` needs `existing_hvn_peering_id = ""`.
- The Client VPN needs `vpc_id`, `subnet_id`, and `client_vpn_cidr` with no
  address-range overlap; a peering needs `vpc_id` and `subnet_id` with no
  VPC / HVN overlap.
- Audit logging on needs exactly one destination: managed CloudWatch, or one
  `audit_log_<vendor>` object.

## Networking enablement

`public_link` decides whether a Client VPN or a peering can exist. On a private
cluster, `enable_vpn` and `create_hvn_peering` are independent opt-ins, and
`manage_peering_routes` applies once a peering is in play.

| `public_link` | `enable_vpn` | `create_hvn_peering` | `existing_hvn_peering_id` | `manage_peering_routes` | Result                                                                                  |
|:-------------:|:------------:|:--------------------:|:-------------------------:|:-----------------------:|-----------------------------------------------------------------------------------------|
|     unset     |      —       |          —           |             —             |            —            | Plan fails: `public_link` must be set                                                   |
|    `true`     |     any      |         any          |            any            |           any           | Public endpoint. No VPN, no peering. Any networking value set produces a warning.       |
|    `false`    |    unset     |          —           |             —             |            —            | Plan fails: `enable_vpn` must be set                                                    |
|    `false`    |    `true`    |          —           |             —             |            —            | Client VPN created (needs `vpc_id`, `subnet_id`, `client_vpn_cidr`)                     |
|    `false`    |   `false`    |          —           |             —             |            —            | No Client VPN — warning to provide another path to Vault                                |
|    `false`    |     set      |        unset         |             —             |            —            | Plan fails: `create_hvn_peering` must be set                                            |
|    `false`    |     set      |        `true`        |            set            |            —            | Plan fails: create and adopt are mutually exclusive                                     |
|    `false`    |     set      |        `true`        |           `""`            |          unset          | Plan fails: `manage_peering_routes` must be set                                         |
|    `false`    |     set      |        `true`        |           `""`            |         `true`          | Peering created, both routes managed                                                    |
|    `false`    |     set      |        `true`        |           `""`            |         `false`         | Peering created, no routes — warning to add both yourself                               |
|    `false`    |     set      |       `false`        |            set            |         `true`          | Peering adopted, both routes managed                                                    |
|    `false`    |     set      |       `false`        |            set            |         `false`         | Peering adopted, no routes — warning                                                    |
|    `false`    |     set      |       `false`        |           `""`            |           any           | No peering — warning that `manage_peering_routes` and `hvn_route_table_ids` are ignored |

Warnings print at the end of `plan` and `apply` and never stop the run.
