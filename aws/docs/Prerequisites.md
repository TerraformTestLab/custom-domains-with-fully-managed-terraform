# Prerequisites

[← Back to README](../README.md)

`terraform` >= 1.15.4, plus credentials in your environment (or on the HCP
Terraform workspace, if you use one):

- **AWS** — `AWS_PROFILE` / `AWS_ACCESS_KEY_ID` / … with permissions for Route53,
  ACM, EC2 Client VPN, VPC peering, route tables, and IAM (only when the managed
  CloudWatch audit path is on).
- **HCP** — `HCP_CLIENT_ID` / `HCP_CLIENT_SECRET` for a service principal in the
  project that owns the HVN and cluster.

Everything else is a resource dependency. For each, whether this config can
create it and whether you can point it at an existing one:

| Dependency                             | This config can create it                                 | Bring your own instead                                                                                                                                                                                                                                                                                                                                      |
|----------------------------------------|-----------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| HCP project                            | No                                                        | Yes — `hcp_project_id`                                                                                                                                                                                                                                                                                                                                      |
| HCP **HVN**                            | **No** — read-only (`data.hcp_hvn`)                       | Yes — `hvn_id` (required); its CIDR and region are read from HCP                                                                                                                                                                                                                                                                                            |
| Public **Route53 hosted zone**         | No                                                        | Yes — `route53_hosted_zone_name` (required, must be public)                                                                                                                                                                                                                                                                                                 |
| HCP **Vault cluster**                  | **Yes** — `create_cluster = true` (`vault_tier` required) | Yes — `create_cluster = false` (default), adopts `cluster_id` read-only                                                                                                                                                                                                                                                                                     |
| AWS **VPC**                            | No                                                        | Yes — `vpc_id`; required on a private cluster whenever the Client VPN (`enable_vpn = true`) or an HVN peering (created or adopted) is active                                                                                                                                                                                                                |
| AWS **private subnet**                 | No                                                        | Yes — `subnet_id`; must belong to `vpc_id`; required alongside `vpc_id`                                                                                                                                                                                                                                                                                     |
| HVN ⇄ VPC **peering**                  | **Yes** — `create_hvn_peering = true`                     | Yes — `create_hvn_peering = false` + `existing_hvn_peering_id` set: the peering was established **outside** this config and is adopted read-only (this config never creates, changes, or deletes the connection, only routes through it). Or both `""` — no peering managed here, connectivity assumed to exist elsewhere (Transit Gateway, Direct Connect) |
| **Peering routes** (both directions)   | **Yes** — `manage_peering_routes = true`                  | Yes — `manage_peering_routes = false`; both routes must already exist. Independent of whether the peering is created or adopted                                                                                                                                                                                                                             |
| Route53 CNAME records                  | Always created                                            | —                                                                                                                                                                                                                                                                                                                                                           |
| Client VPN endpoint + mTLS certs (ACM) | Created when `enable_vpn = true` (private clusters only)  | — never adopted                                                                                                                                                                                                                                                                                                                                             |
| Audit-log destination                  | **CloudWatch** — `cloudwatch_audit_log_enabled`           | External sinks (Datadog, Splunk, …) must already exist                                                                                                                                                                                                                                                                                                      |

The HVN, VPC, subnet, and cluster must all be in `aws_region` — the plan fails if
the HVN's region disagrees.

`public_link` has no default and must be set (`true` or `false`). On a private
cluster (`public_link = false`) so must `enable_vpn` and `create_hvn_peering`,
and `manage_peering_routes` once a peering is in play. A public cluster
(`public_link = true`) needs none of them — no VPN or peering is ever created.

## You must add your project to the following LD flags

| LD Flag                                                                                                                                                                            | Purpose                                                                                                                                 |
|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------|
| [Feature Enablement LD Flag](https://app.launchdarkly.com/projects/cloud-services/flags/hcpv-custom-domain-enabled/targeting?env=dev&env=production&env=int&selected-env=dev)      | Enables the custom domain feature for your project.                                                                                     |
| [API throttling LD flag](https://app.launchdarkly.com/projects/cloud-services/flags/hcpv-custom-domain-throttle-enabled/targeting?env=dev&env=production&env=int&selected-env=dev) | Default value `true`. Set it to `false` for your project if you want to retry without throttling through exponential backoff and retry. |
