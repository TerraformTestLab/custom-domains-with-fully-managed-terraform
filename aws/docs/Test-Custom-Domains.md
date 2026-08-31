# Test the custom domain

[← Back to README](../README.md)

End-to-end checks for a private cluster once the custom domain is enabled: the
domain resolves, the Client VPN reaches the private HVN, Vault serves a valid
Let's Encrypt certificate, and the API answers on it.

Run this after [Enable-Custom-Domains.md](Enable-Custom-Domains.md) reports
`is_enabled: true` and its operation is `DONE`. For the pre-enable checklist see
[Validate-Resources-Required-For-Custom-Domains.md](Validate-Resources-Required-For-Custom-Domains.md).

On a public cluster (`public_link = true`), skip section 1 and every VPN check;
the endpoint is reachable from anywhere. Sections 2 to 7 apply as written.

Collect the values the checks use:

```shell
cd terraform-fully-managed/aws

CNAME_FQDN=$(terraform output -raw vault_cname_fqdn)             # vault.<zone>
CHALLENGE_FQDN=$(terraform output -raw vault_challenge_cname_fqdn)
PRIV_URL=$(terraform output -raw vault_private_endpoint_url)     # https://<private-host>:8200
PRIV_HOSTPORT=${PRIV_URL#https://}
HVN_CIDR=$(terraform output -raw hvn_cidr)
AWS_REGION=<same value as aws_region in terraform.tfvars>
```

## 1. Connect the Client VPN

```shell
terraform output -raw ovpn_file_content > vault-client-vpn.ovpn
chmod 600 vault-client-vpn.ovpn
# import vault-client-vpn.ovpn into Tunnelblick / OpenVPN Connect / AWS VPN Client
# and connect

# confirm the tunnel came up with an address from client_vpn_cidr:
ip -4 addr show 2>/dev/null | grep -E 'tun|utun' || ifconfig | grep -A2 -E 'tun|utun'
```

## 2. DNS resolution

```shell
dig +short CNAME "$CNAME_FQDN"        # => <vault_target_hostname>.
dig +short CNAME "$CHALLENGE_FQDN"    # => _acme-challenge.<vault_target_hostname>.
dig +short        "$CNAME_FQDN"       # => an address inside $HVN_CIDR (e.g. 172.25.x.x)
```

A public IP or an empty result on the last line means the VPN DNS path is not in
effect — reconnect the tunnel (and reconnect again after any Wi-Fi change).

## 3. Reachability on port 8200

```shell
nc -zvw3 "$CNAME_FQDN"         8200      # custom domain — must succeed
nc -zvw3 "${PRIV_HOSTPORT%:*}" 8200      # private hostname (control) — must succeed
```

- Both fail → VPN down, peering not `active`, or the subnet route to the HVN is
  missing (section 6).
- Private hostname works, custom domain fails → DNS/CNAME problem, not network
  (section 2; wait out the 300s record TTL).

## 4. TLS certificate

```shell
echo | openssl s_client -connect "${CNAME_FQDN}:8200" -servername "$CNAME_FQDN" 2>/dev/null \
  | openssl x509 -noout -dates -subject -issuer -ext subjectAltName
```

Pass:

- `issuer=` contains **Let's Encrypt** (not `vpn-ca.hcp.vault` or an HCP internal
  CA — that would mean the certificate has not been issued yet)
- `subjectAltName` includes `DNS:<your custom domain>`
- `notAfter` is a valid future date (~90 days out)

## 5. Vault API over the custom domain

No `-k` / `-tls-skip-verify` anywhere — the certificate must chain to a public
root.

```shell
curl -sS "https://${CNAME_FQDN}:8200/v1/sys/health"      | jq '{initialized, sealed, standby, version}'
curl -sS "https://${CNAME_FQDN}:8200/v1/sys/seal-status" | jq '{sealed, initialized}'
```

Pass: `initialized: true`, `sealed: false`. HTTP 429 / 473 / 501 is a
standby / performance-standby / DR node — not an error.

## 6. Vault CLI login on the custom domain

```shell
export VAULT_ADDR="https://${CNAME_FQDN}:8200"

vault hcp connect -client-id=<HCP_CLIENT_ID> -secret-id=<HCP_CLIENT_SECRET>   # or: vault login <token>
vault status
vault token lookup
```

Pass: `vault status` shows `Sealed: false`; `vault token lookup` returns your
token metadata — with no TLS override.

## 7. Infrastructure and HCP-side confirmation

```shell
VPN_EP=$(terraform output -raw vpn_endpoint_id)
PCX=$(terraform output -raw aws_peering_connection_id)

aws ec2 describe-vpc-peering-connections --region "$AWS_REGION" \
  --vpc-peering-connection-ids "$PCX" \
  --query 'VpcPeeringConnections[0].Status.Code' --output text          # active

aws ec2 describe-client-vpn-endpoints --region "$AWS_REGION" \
  --client-vpn-endpoint-ids "$VPN_EP" \
  --query 'ClientVpnEndpoints[0].Status.Code' --output text             # available

aws ec2 describe-client-vpn-connections --region "$AWS_REGION" \
  --client-vpn-endpoint-id "$VPN_EP" \
  --query "Connections[?Status.Code=='active'].[CommonName, ClientIp]" --output table   # your live session

curl -sS "https://${HCP_API_ADDRESS}/vault/2020-11-25/organizations/${HCP_ORGANIZATION_ID}/projects/${HCP_PROJECT_ID}/clusters/${HCP_VAULT_ID}" \
  -H "Authorization: Bearer $(hcp auth print-access-token)" \
  | jq '.cluster.config.network_config.custom_domain_config, .cluster.dns_names'
```

(The `HCP_*` variables — `HCP_API_ADDRESS`, `HCP_ORGANIZATION_ID`,
`HCP_PROJECT_ID`, `HCP_VAULT_ID` — are set in
[Enable-Custom-Domains.md](Enable-Custom-Domains.md) steps 1–2.)

## Quick all-in-one

```shell
echo "=== CNAME ==="        && dig +short CNAME "$CNAME_FQDN" && \
echo "=== HVN resolution ===" && dig +short "$CNAME_FQDN" && \
echo "=== port 8200 ==="     && nc -zvw3 "$CNAME_FQDN" 8200 && \
echo "=== health ==="        && curl -sS "https://${CNAME_FQDN}:8200/v1/sys/health" | jq '{initialized, sealed}' && \
echo "=== certificate ==="   && echo | openssl s_client -connect "${CNAME_FQDN}:8200" -servername "$CNAME_FQDN" 2>/dev/null | openssl x509 -noout -issuer -ext subjectAltName
```

All green when: CNAME correct → resolves inside `$HVN_CIDR` → port 8200 open →
health returns JSON over a Let's Encrypt certificate whose SAN is the custom
domain.

## Troubleshooting

| Symptom                                                       | Likely cause                                                                | Fix                                                                                                                                                                                   |
|---------------------------------------------------------------|-----------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `dig` CNAME empty                                             | Route53 records not applied                                                 | re-run `terraform apply`; check `terraform output vault_cname_fqdn`                                                                                                                   |
| CNAME resolves but `dig +short` returns a public IP           | VPN not connected / split-tunnel DNS not applied                            | reconnect `vault-client-vpn`; reconnect after Wi-Fi changes                                                                                                                           |
| `nc` fails to both custom domain and private hostname         | VPN down, peering not `active`, or subnet route missing                     | section 7; re-check `terraform output hvn_peering_state` and `hvn_peering_aws_route_table_ids`                                                                                        |
| `nc` to private hostname works, custom domain fails           | CNAME wrong or not propagated                                               | section 2; wait for the 300s TTL                                                                                                                                                      |
| `curl` TLS error, or issuer is `vpn-ca.hcp.vault` / an HCP CA | custom-domain certificate not issued yet                                    | re-check [Enable-Custom-Domains.md](Enable-Custom-Domains.md) → *Track the certificate workflow*; confirm `_acme-challenge` resolves publicly; wait for the operation to reach `DONE` |
| HCP operation stuck or errored                                | ACME DNS-01 challenge cannot resolve                                        | `dig +short CNAME "$CHALLENGE_FQDN" @8.8.8.8`; then re-send the PATCH                                                                                                                 |
| health returns 429 / 473 / 501                                | standby / perf-standby / DR node — not an error                             | confirm with `/v1/sys/seal-status`                                                                                                                                                    |
| `vault login` only works with `-tls-skip-verify`              | `VAULT_ADDR` not on the custom domain, or the cert check in section 4 fails | set `VAULT_ADDR` to the custom domain; re-run section 4                                                                                                                               |

When everything passes and you are done, tear it all down with
[Cleanup.md](Cleanup.md).
