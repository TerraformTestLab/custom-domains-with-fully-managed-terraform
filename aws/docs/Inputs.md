# Inputs

[← Back to README](../README.md)

Every variable below is set in `terraform.tfvars`. String variables default to
`""`; the deployment-specific ones ship as `REPLACE_WITH_*` placeholders whose
comment names the console to get the value from. A placeholder or an unset
required value fails validation, so the plan names exactly which input is missing
instead of assuming a default.

The four networking booleans — `public_link`, `enable_vpn`, `create_hvn_peering`,
`manage_peering_routes` — have **no default**. Networking is never automatic: the
root module errors out (with a message naming the variable) until each one that
applies is set explicitly. See [Networking enablement](#networking-enablement).

The main table below keeps only the two audit-log switches, `audit_log_enabled`
and `cloudwatch_audit_log_enabled`. The destination and tuning inputs are
collected under [Audit-log inputs](#audit-log-inputs).

| Variable                       | Default                 | Purpose                                                                                                                                                                                                                                                                                     |
|--------------------------------|-------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `aws_region`                   | `""`                    | AWS region for every regional resource (ACM, Client VPN, peering, routes). Must equal the HVN / VPC / subnet region                                                                                                                                                                         |
| `hcp_project_id`               | `""`                    | HCP project that owns the HVN and Vault cluster                                                                                                                                                                                                                                             |
| `route53_hosted_zone_name`     | `""`                    | Existing public Route53 hosted zone the Vault record is created in                                                                                                                                                                                                                          |
| `vault_record_name`            | `""`                    | Left-most label of the custom domain — must be `vault` (the domain is always `vault.<zone>`); empty or any other value fails validation                                                                                                                                                     |
| `cluster_id`                   | `""`                    | ID of the Vault cluster this config manages — created when `create_cluster`, adopted read-only otherwise                                                                                                                                                                                    |
| `create_cluster`               | `false`                 | `true` creates the cluster; `false` adopts an existing one with `cluster_id`                                                                                                                                                                                                                |
| `public_link`                  | **required**            | `true` → custom domain targets the public endpoint and **no** Client VPN or HVN peering is ever created (every networking var below is ignored). `false` → targets the private endpoint; `enable_vpn` and `create_hvn_peering` must then also be set. No default — the plan errors if unset |
| `vault_tier`                   | `""`                    | HCP Vault tier. Required when `create_cluster = true`; must be `""` when adopting                                                                                                                                                                                                           |
| `min_vault_version`            | `null`                  | Minimum Vault version (`vX.Y.Z`); `null` selects latest. Applied only when creating                                                                                                                                                                                                         |
| `audit_log_enabled`            | `false`                 | Master switch for Vault audit-log streaming. Destination and tuning inputs: [Audit-log inputs](#audit-log-inputs)                                                                                                                                                                           |
| `cloudwatch_audit_log_enabled` | `false`                 | When audit is on, have Terraform create + manage the CloudWatch destination instead of pointing at an external sink                                                                                                                                                                         |
| `vpc_id`                       | `""`                    | AWS VPC peered to the HVN and hosting the Client VPN. Required when the VPN or a peering is active                                                                                                                                                                                          |
| `subnet_id`                    | `""`                    | Private subnet inside `vpc_id` for the VPN association / HVN route table. Required when the VPN or a peering is active                                                                                                                                                                      |
| `client_vpn_cidr`              | `""`                    | Non-overlapping IPv4 CIDR (`/22` or larger) for VPN clients. Required when the Client VPN is active                                                                                                                                                                                         |
| `enable_vpn`                   | **required if private** | `true` → create the AWS Client VPN. `false` → skip it (a warning notes that a path to Vault must exist outside this config). Ignored when `public_link = true`. No default                                                                                                                  |
| `hvn_id`                       | `""`                    | ID of the existing HCP HVN that hosts the cluster and peers with the VPC. Read-only, never created                                                                                                                                                                                          |
| `create_hvn_peering`           | **required if private** | `true` → create + accept a new HVN⇄VPC peering (`existing_hvn_peering_id` must be `""`). `false` → adopt `existing_hvn_peering_id` if set, else manage no peering at all. Ignored when `public_link = true`. No default                                                                     |
| `existing_hvn_peering_id`      | `""`                    | HCP-side slug of a peering **already established outside this config**. When set, Terraform only reads it (`data` source) and routes through it — it never creates, changes, or deletes the connection. Must be `""` when `create_hvn_peering = true`                                       |
| `manage_peering_routes`        | **required if peering** | `true` → Terraform manages **both** route directions. `false` → manages neither (a warning notes both must already exist). Independent of `create_hvn_peering`. Required only when a peering is created or adopted. No default                                                              |
| `hvn_route_table_ids`          | `[]`                    | Explicit route tables to carry the HVN route. `[]` → the route table associated with `subnet_id`. Ignored unless Terraform manages peering routes                                                                                                                                           |

## Audit-log inputs

`audit_log_enabled` and `cloudwatch_audit_log_enabled` (in the table above) are
the only audit-log switches. The inputs below are consulted **only when
`audit_log_enabled = true`**:

- `cloudwatch_audit_log_enabled = true` → Terraform manages the CloudWatch
  destination; `cloudwatch_audit_log_group_name` and
  `cloudwatch_audit_log_retention_days` tune it, and no `audit_log_<vendor>`
  object may be set.
- `cloudwatch_audit_log_enabled = false` → set **exactly one** `audit_log_<vendor>`
  object; `audit_log_sink_count` (default `1`) is how many HCP expects.

| Variable                              | Default | Purpose                                                                                                     |
|---------------------------------------|---------|-------------------------------------------------------------------------------------------------------------|
| `audit_log_sink_count`                | `1`     | Number of external `audit_log_<vendor>` objects required on the external-sink path. HCP accepts exactly one |
| `cloudwatch_audit_log_group_name`     | `""`    | Override the managed log group name. `""` derives `/hcp/vault/<cluster_id>/audit`                           |
| `cloudwatch_audit_log_retention_days` | `30`    | Retention for the managed log group in days; `0` keeps forever                                              |
| `audit_log_cloudwatch`                | `null`  | External sink — a CloudWatch log group + IAM credentials you manage yourself                                |
| `audit_log_datadog`                   | `null`  | External sink — Datadog                                                                                     |
| `audit_log_elasticsearch`             | `null`  | External sink — Elasticsearch                                                                               |
| `audit_log_grafana`                   | `null`  | External sink — Grafana Loki                                                                                |
| `audit_log_splunk`                    | `null`  | External sink — Splunk HTTP Event Collector                                                                 |
| `audit_log_newrelic`                  | `null`  | External sink — New Relic                                                                                   |
| `audit_log_http`                      | `null`  | External sink — generic HTTP                                                                                |

Per-field validation for these inputs is in [Validation rules](#validation-rules);
how they interact with `audit_log_enabled` and `create_cluster` is in [Variable
dependencies](#variable-dependencies). The full control model — switch matrix,
what each module builds, and the security note — is in [Audit logging
configuration](Optional-Reading.md#audit-logging-configuration).

## Validation rules

| Variable                                                 | Rule                                                                                                        | Reason                                                                                                                                                   |
|----------------------------------------------------------|-------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------|
| `aws_region`, `audit_log_cloudwatch.region`              | `^[a-z]{2}-[a-z]+-\d$`                                                                                      | Must be a real AWS region code — it drives every regional resource                                                                                       |
| `hcp_project_id`                                         | UUID                                                                                                        | HCP project IDs are UUIDs; a wrong shape fails before any API call                                                                                       |
| `route53_hosted_zone_name`                               | bare domain, no scheme / trailing dot                                                                       | Passed straight to the Route53 zone lookup and record names                                                                                              |
| `vault_record_name`                                      | must be exactly `vault`                                                                                     | The custom domain is always `vault.<zone>`; empty (the default) or any other label fails                                                                 |
| `cluster_id`, `hvn_id`, `existing_hvn_peering_id`        | HCP slug: 3–36 chars, lowercase alphanumeric/hyphen, no leading/trailing hyphen                             | Matches HCP's own ID rules; the `REPLACE_WITH_*` placeholder fails on purpose. `existing_hvn_peering_id` is the HCP-side slug, **not** the AWS `pcx-` id |
| `public_link`                                            | must be non-null (`true` or `false`)                                                                        | Networking has no default — the choice is always conscious. Enforced by `terraform_data.root_preflight`                                                  |
| `enable_vpn`, `create_hvn_peering`                       | non-null when `public_link = false`                                                                         | The Client VPN and HVN peering are per-concern opt-ins, never automatic                                                                                  |
| `manage_peering_routes`                                  | non-null when a peering is created or adopted                                                               | Route management is an explicit all-or-nothing choice                                                                                                    |
| `create_hvn_peering` vs `existing_hvn_peering_id`        | not both set                                                                                                | Create a new peering, or adopt an existing one — never both (enforced in `vault-hvn-peering`)                                                            |
| `vault_tier`                                             | `""` or one of `dev`, `starter_small`, `standard_small`/`_medium`/`_large`, `plus_small`/`_medium`/`_large` | Only these tiers exist; `""` is the "adopting" sentinel                                                                                                  |
| `min_vault_version`                                      | `vX.Y.Z` or `null`                                                                                          | HCP version format                                                                                                                                       |
| `vpc_id` / `subnet_id` / `hvn_route_table_ids[*]`        | `""` or `vpc-` / `subnet-` / `rtb-` + 8 or 17 hex                                                           | AWS resource-ID shapes; `""` lets a public cluster skip networking                                                                                       |
| `client_vpn_cidr`                                        | `""` or a valid IPv4 CIDR, prefix ≤ `/22`                                                                   | AWS Client VPN needs a client pool of `/22` or larger; overlap is checked separately at plan time                                                        |
| `cloudwatch_audit_log_retention_days`                    | one of the 23 CloudWatch-allowed values                                                                     | CloudWatch rejects any other retention                                                                                                                   |
| `cloudwatch_audit_log_group_name`                        | `""` or ≤ 512 chars, `[-A-Za-z0-9_./#]`                                                                     | CloudWatch log-group name rules                                                                                                                          |
| `audit_log_sink_count`                                   | `== 1`                                                                                                      | HCP Vault accepts exactly one `audit_log_config`                                                                                                         |
| `audit_log_datadog.region`                               | `us1` / `us3` / `us5` / `eu1` / `ap1` / `us1-fed`                                                           | Datadog site identifiers                                                                                                                                 |
| `audit_log_newrelic.region`                              | `US` / `EU`                                                                                                 | New Relic data-center regions                                                                                                                            |
| `audit_log_{elasticsearch,grafana,splunk,http}` endpoint | must be a URL (`https://` for Elasticsearch)                                                                | These are network endpoints; a non-URL is always a mistake                                                                                               |
| `audit_log_http.method` / `.codec`                       | `POST`/`PUT` · `json`/`ndjson` (when set)                                                                   | Only values HCP's HTTP sink accepts                                                                                                                      |
| `audit_log_cloudwatch`                                   | `access_key_id` and `secret_access_key` set together or not at all                                          | A half-set credential pair can't authenticate                                                                                                            |

## Variable dependencies

| Variables                                                                   | Relationship                | Rule                                                                                                                                                                                                                                     |
|-----------------------------------------------------------------------------|-----------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `create_cluster` ↔ `vault_tier`, `min_vault_version`                        | required-if / forbidden     | `create_cluster = true` ⇒ `vault_tier` set. `create_cluster = false` ⇒ `vault_tier = ""` and `min_vault_version = null`                                                                                                                  |
| `create_cluster` ↔ any `audit_log_*`                                        | forbidden                   | Audit config can't be pushed to an adopted cluster — all audit inputs must be off when `create_cluster = false`                                                                                                                          |
| `public_link` → `enable_vpn`, `create_hvn_peering`, `manage_peering_routes` | gate + conditional-required | `public_link = true` ⇒ all three ignored; the plan succeeds even if they are unset. `public_link = false` ⇒ `enable_vpn` and `create_hvn_peering` are required; `manage_peering_routes` is required once a peering is created or adopted |
| `create_hvn_peering` ↔ `existing_hvn_peering_id`                            | mutually exclusive          | `true` ⇒ `existing_hvn_peering_id = ""`. `false` + `existing_hvn_peering_id = ""` ⇒ no Terraform-managed peering (external connectivity assumed)                                                                                         |
| `create_hvn_peering` ⟂ `manage_peering_routes`                              | independent                 | Every combination is valid — a created peering can leave routes unmanaged, an adopted one can have them managed                                                                                                                          |
| `enable_vpn = true` → `vpc_id`, `subnet_id`, `client_vpn_cidr`              | required-if                 | The Client VPN needs all three; `client_vpn_cidr` must not overlap the VPC or HVN CIDR (checked in `vault-aws-client-vpn`)                                                                                                               |
| peering created or adopted → `vpc_id`, `subnet_id`                          | required-if                 | The peering module needs both; the VPC CIDR(s) must not overlap the HVN CIDR (checked in `vault-hvn-peering`)                                                                                                                            |
| `audit_log_enabled` → `cloudwatch_audit_log_enabled` / `audit_log_<vendor>` | exactly one                 | Audit on ⇒ exactly one destination: managed CloudWatch, or exactly one `audit_log_<vendor>` object. Not both, not neither                                                                                                                |
| `audit_log_enabled` → `create_cluster`                                      | required-if                 | Audit config only applies to a cluster this config creates (checked in `vault-cluster`)                                                                                                                                                  |
| `cloudwatch_audit_log_enabled` → `audit_log_enabled`                        | required-if                 | The CloudWatch path does nothing without the master switch (checked in `cloudwatch-audit-log`)                                                                                                                                           |

## Networking enablement

`public_link` is the only switch that decides whether a Client VPN or an HVN
peering can exist. `enable_vpn` and `create_hvn_peering` are separate, conscious
opt-ins for a private cluster. `·` in the table means "unset / any value" — for a
public cluster the value genuinely does not matter and the plan does not fail.

| `public_link` | `enable_vpn` |  `create_hvn_peering`  | `existing_hvn_peering_id` | `manage_peering_routes` |      Client VPN      | HVN peering  | Routes | End-of-run notice                                                                                                            |
|:-------------:|:------------:|:----------------------:|:-------------------------:|:-----------------------:|:--------------------:|:------------:|:------:|------------------------------------------------------------------------------------------------------------------------------|
|    *unset*    |      —       |           —            |             —             |            —            |          —           |      —       |   —    | ❌ `public_link must be set`                                                                                                  |
|    `true`     |     `·`      |          `·`           |            `·`            |           `·`           |          ✗           |      ✗       |   —    | ⚠️ only if a networking var is `true` / non-empty: "ignored — a public cluster never gets VPN or peering"                    |
|    `false`    |   *unset*    |           —            |             —             |            —            |          —           |      —       |   —    | ❌ `enable_vpn must be set`                                                                                                   |
|    `false`    |   `false`    | *(peering cols below)* |                           |                         |          ✗           | *(per cols)* |   —    | ⚠️ "Client VPN not created — assuming an external path to Vault (Transit Gateway, Direct Connect, existing VPN)"             |
|    `false`    |    `true`    | *(peering cols below)* |                           |                         |          ✔           | *(per cols)* |   —    | needs `vpc_id`, `subnet_id`, `client_vpn_cidr`; no CIDR overlap → else ❌                                                     |
|    `false`    |     set      |        *unset*         |             —             |            —            | *(per `enable_vpn`)* |      —       |   —    | ❌ `create_hvn_peering must be set`                                                                                           |
|    `false`    |     set      |        `false`         |           `""`            |           `·`           | *(per `enable_vpn`)* |      ✗       |   —    | ⚠️ "no Terraform-managed peering — `manage_peering_routes` and `hvn_route_table_ids` ignored; external connectivity assumed" |
|    `false`    |     set      |         `true`         |            set            |           `·`           |          —           |      —       |   —    | ❌ mutually exclusive                                                                                                         |
|    `false`    |     set      |         `true`         |           `""`            |         *unset*         |          —           |      —       |   —    | ❌ `manage_peering_routes must be set`                                                                                        |
|    `false`    |     set      |         `true`         |           `""`            |         `true`          |          —           |   ✔ create   | ✔ both | —                                                                                                                            |
|    `false`    |     set      |         `true`         |           `""`            |         `false`         |          —           |   ✔ create   |   ✗    | ⚠️ "peering created, routes unmanaged — add both directions yourself"                                                        |
|    `false`    |     set      |        `false`         |            set            |         `true`          |          —           |   ✔ adopt    | ✔ both | —                                                                                                                            |
|    `false`    |     set      |        `false`         |            set            |         `false`         |          —           |   ✔ adopt    |   ✗    | ⚠️ "adopting a peering without managing routes — ensure both directions already exist"                                       |
|    `false`    |    `true`    |     peering active     |                           |                         |          ✔           |      ✔       |        | ❌ if `vpc_id` / `subnet_id` unset, or any CIDR pair overlaps                                                                 |

Details of the audit-log switches are in [Audit logging
configuration](Optional-Reading.md#audit-logging-configuration).

Several conditions only produce a **warning** at the end of plan and apply, never
a failure:

- `public_link = true` with any networking var set — all are ignored;
- private cluster, `enable_vpn = false` — no Client VPN; ensure another path to Vault exists;
- private cluster, `create_hvn_peering = false` and `existing_hvn_peering_id = ""` — no Terraform-managed peering; `manage_peering_routes` and `hvn_route_table_ids` ignored;
- a peering created or adopted with `manage_peering_routes = false` — make sure both route directions already exist;
- `hvn_route_table_ids` set while Terraform is not managing peering routes — no effect.

And two things can only be confirmed at apply: whether the managed CloudWatch IAM
policy satisfies HCP's writer, and whether `audit_log_config` is truly
non-`ForceNew`.
