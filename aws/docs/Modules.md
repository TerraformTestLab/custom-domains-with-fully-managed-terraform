# Modules

[← Back to README](../README.md)

The root configuration composes four modules.

| Module                        | Runs                                                               | Purpose                                                                                                                                                                                                                                                                    |
|-------------------------------|--------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `vault-cluster`               | Always                                                             | Creates the Vault cluster, or reads an existing one, and works out the hostname the custom-domain record points at.                                                                                                                                                       |
| `vault-custom-domain-records` | Always                                                             | Creates the `vault.<zone>` CNAME and the matching `_acme-challenge` CNAME that Let's Encrypt checks.                                                                                                                                                                       |
| `vault-hvn-peering`           | Private cluster, with a peering created or adopted                 | Creates the HVN ⇄ VPC peering, or reads an existing one, and — when `manage_peering_routes = true` — writes the routes on both sides. Checks that the VPC and subnet are given and that the VPC and HVN address ranges do not overlap.                                     |
| `vault-aws-client-vpn`        | Private cluster, `enable_vpn = true`                               | Issues a self-signed mTLS CA and certificates into ACM, stands up the Client VPN endpoint on the private subnet, authorises and routes the VPC and HVN ranges, and writes the `.ovpn` profile. Checks that the VPC, subnet, and client CIDR are given and non-overlapping. |

How the modules connect is in [Optional-Reading.md](Optional-Reading.md).
