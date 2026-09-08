# Modules

[← Back to README](../README.md)

The root configuration composes five modules.

| Module                        | Runs                                                               | Purpose                                                                                                                                                                                                                                                                    |
|-------------------------------|--------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `vault-cluster`               | Always                                                             | Creates the Vault cluster, or reads an existing one, and works out the hostname the custom-domain record points at. Attaches the audit-log configuration when one is set.                                                                                                  |
| `vault-custom-domain-records` | Always                                                             | Creates the `vault.<zone>` CNAME and the matching `_acme-challenge` CNAME that Let's Encrypt checks.                                                                                                                                                                       |
| `vault-hvn-peering`           | Private cluster, with a peering created or adopted                 | Creates the HVN ⇄ VPC peering, or reads an existing one, and — when `manage_peering_routes = true` — writes the routes on both sides. Checks that the VPC and subnet are given and that the VPC and HVN address ranges do not overlap.                                     |
| `vault-aws-client-vpn`        | Private cluster, `enable_vpn = true`                               | Issues a self-signed mTLS CA and certificates into ACM, stands up the Client VPN endpoint on the private subnet, authorises and routes the VPC and HVN ranges, and writes the `.ovpn` profile. Checks that the VPC, subnet, and client CIDR are given and non-overlapping. |
| `cloudwatch-audit-log`        | `audit_log_enabled = true`                                         | Creates the CloudWatch log group, a dedicated least-privilege IAM user, and an access key for audit-log streaming, and builds the `audit_log_config` payload the cluster needs.                                                                                             |

How the modules connect, and why audit logging is shaped this way, is in
[Optional-Reading.md](Optional-Reading.md).
