# Modules

[← Back to README](../README.md)

The root configuration composes six modules.

| Module                        | Runs                                                               | Purpose                                                                                                                                                                                                                                                                    |
|-------------------------------|--------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `vault-cluster`               | Always                                                             | Creates the Vault cluster, or reads an existing one, and works out the hostname the custom-domain record points at. Attaches the audit-log configuration when one is set.                                                                                                  |
| `vault-custom-domain-records` | Always                                                             | Creates the `vault.<zone>` CNAME and the matching `_acme-challenge` CNAME that Let's Encrypt checks.                                                                                                                                                                       |
| `vault-hvn-peering`           | Private cluster, with a peering created or adopted                 | Creates the HVN ⇄ VPC peering, or reads an existing one, and — when `manage_peering_routes = true` — writes the routes on both sides. Checks that the VPC and subnet are given and that the VPC and HVN address ranges do not overlap.                                     |
| `vault-aws-client-vpn`        | Private cluster, `enable_vpn = true`                               | Issues a self-signed mTLS CA and certificates into ACM, stands up the Client VPN endpoint on the private subnet, authorises and routes the VPC and HVN ranges, and writes the `.ovpn` profile. Checks that the VPC, subnet, and client CIDR are given and non-overlapping. |
| `cloudwatch-audit-log`        | `audit_log_enabled` and `cloudwatch_audit_log_enabled` both `true` | Creates the CloudWatch log group and a dedicated least-privilege IAM user for audit-log streaming.                                                                                                                                                                         |
| `vault-audit-log`             | `audit_log_enabled = true`, `cloudwatch_audit_log_enabled = false` | Packages the credentials for an external sink — Datadog, Splunk, Elasticsearch, Grafana, New Relic, HTTP, or a self-managed CloudWatch group. Creates no resources.                                                                                                        |

How the modules connect, and why audit logging is shaped this way, is in
[Optional-Reading.md](Optional-Reading.md).
