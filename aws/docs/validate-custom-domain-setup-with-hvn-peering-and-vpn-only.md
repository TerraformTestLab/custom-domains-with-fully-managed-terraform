# Validate the setup before enabling the custom domain

[← Back to README](../README.md)

Run this **after `terraform apply` succeeds** and **before** you fire the HCP API
call that enables the custom domain. Every check is read-only. When a section's
Go / No-Go table is green, HCP has what it needs to request the Let's Encrypt
certificate and serve it on `vault.<zone>`.

Pick the section that matches your cluster:

- **[Section A. Public clusters](#section-a-public-clusters)** — `public_link = true`
- **[Section B. Private-only clusters (HVN peering and VPN)](#section-b-private-only-clusters-hvn-peering-and-vpn)** —
  `public_link = false`, `enable_vpn = true`, and an HVN peering created or
  adopted with `manage_peering_routes = true`


## Before you start

- Tools on PATH: `terraform`, `dig`, `curl`, `jq`, `openssl`, `aws`, `hcp`, and
  (Section B) an OpenVPN client.
- Shell configured per [Prepare-Environment.md](Prepare-Environment.md) — AWS
  credentials, and `HCP_API_ADDRESS` plus a fresh `HCP_API_TOKEN`.
- Your project is on the `hcpv-custom-domain-enabled` LaunchDarkly flag
  ([Prerequisites.md](Prerequisites.md#you-must-add-your-project-to-the-following-ld-flags)).

Collect the values every section uses:

```shell
cd terraform-fully-managed/aws

CNAME_FQDN=$(terraform output -raw vault_cname_fqdn)                # vault.<zone>
CHALLENGE_FQDN=$(terraform output -raw vault_challenge_cname_fqdn)  # _acme-challenge.vault.<zone>
TARGET_HOST=$(terraform output -raw vault_target_hostname)         # bare hcp.to host the CNAME points at
ZONE=${CNAME_FQDN#vault.}                                          # the Route53 hosted zone
CLUSTER_ID=$(terraform output -raw vault_cluster_id)
AWS_REGION=<same value as aws_region in terraform.tfvars>

# for the HCP API calls (A.6 and the enable step)
HCP_PROJECT_ID=<hcp_project_id from terraform.tfvars>
HCP_ORGANIZATION_ID=$(hcp organizations list --format=json | jq -r '.[0].id')   # or copy from the HCP portal
```

---

## Section A. Public clusters

`public_link = true`. The endpoint is reachable from anywhere; no VPN, no peering.

### A.1 Terraform converged and the outputs are what you expect

```shell
terraform plan -detailed-exitcode   # exit 0 = no drift; exit 2 = drift, fix before continuing

terraform output is_public_endpoint          # true
terraform output vpn_enabled                 # false
terraform output hvn_peering_enabled         # false
PUB_URL=$(terraform output -raw vault_public_endpoint_url)   # must be non-empty
echo "$PUB_URL" | grep -q "$TARGET_HOST" && echo "target host matches the public endpoint"
```

### A.2 The Route53 zone is public and delegated

```shell
dig +short NS "$ZONE" @1.1.1.1       # must return Route53 nameservers (ns-*.awsdns-*)
```

No answer from a public resolver ⇒ the zone is not delegated or not public.
Let's Encrypt validates the ACME challenge over the public internet, so this is a
hard blocker even though the cluster is public.

### A.3 Both records are live on public DNS

```shell
dig +short CNAME "$CNAME_FQDN"     @1.1.1.1   # => <TARGET_HOST>.
dig +short CNAME "$CHALLENGE_FQDN" @1.1.1.1   # => _acme-challenge.<TARGET_HOST>.
dig +short        "$CNAME_FQDN"    @1.1.1.1   # => the public IP(s) of the HCP endpoint
```

The `_acme-challenge` record is what Let's Encrypt's DNS-01 check reads; if it is
missing or points at the wrong host, issuance fails.

### A.4 The endpoint answers and Vault is healthy

```shell
curl -sS "${PUB_URL}/v1/sys/health" | jq '{initialized, sealed, standby, version}'
# expect initialized=true, sealed=false
```

### A.5 TLS still serves the default HCP certificate (expected pre-enable)

```shell
HOSTPORT=${PUB_URL#https://}
echo | openssl s_client -connect "$HOSTPORT" -servername "$CNAME_FQDN" 2>/dev/null \
  | openssl x509 -noout -subject -issuer -ext subjectAltName
```

Pre-enable the SAN lists the `*.hcp.to` host, **not** `vault.<zone>`. That is
correct — it flips to a Let's Encrypt certificate with `vault.<zone>` in the SAN
after you enable the domain.

### A.6 HCP is ready for the call

```shell
hcp auth print-access-token >/dev/null && echo "HCP auth OK"

curl -sS "https://${HCP_API_ADDRESS}/vault/2020-11-25/organizations/${HCP_ORGANIZATION_ID}/projects/${HCP_PROJECT_ID}/clusters/${CLUSTER_ID}" \
  -H "Authorization: Bearer ${HCP_API_TOKEN}" \
  | jq '.cluster.config.network_config.custom_domain_config // "not set"'
# expect "not set" or is_enabled=false — the domain must not already be enabled
```

### Section A — Go / No-Go

| Check                | Pass criteria                                        | Blocks enable?           |
|----------------------|------------------------------------------------------|--------------------------|
| A.1 `terraform plan` | exit code 0                                          | **yes**                  |
| A.1 outputs          | `is_public_endpoint = true`, public URL non-empty    | **yes**                  |
| A.2 zone delegation  | NS = `awsdns-*` from a public resolver               | **yes**                  |
| A.3 CNAME records    | both resolve via `@1.1.1.1`                          | **yes**                  |
| A.4 Vault health     | HTTP 200, `sealed=false`                             | **yes**                  |
| A.6 HCP readiness    | token prints, domain not already enabled, LD flag on | **yes**                  |
| A.5 TLS              | SAN = `*.hcp.to`                                     | no — expected pre-enable |

All **yes** rows green ⇒ go to [Enable the custom domain](#enable-the-custom-domain).

---

## Section B. Private-only clusters (HVN peering and VPN)

`public_link = false`, `enable_vpn = true`, an HVN peering created or adopted, and
`manage_peering_routes = true`. Vault is reachable only from inside the peered VPC
— that is, from your laptop once the Client VPN is connected.

### B.1 Terraform converged and the outputs are what you expect

```shell
terraform plan -detailed-exitcode   # exit 0 = no drift; exit 2 = drift, fix before continuing

terraform output is_private_endpoint              # true
terraform output vault_public_endpoint_url        # empty
terraform output vpn_enabled                      # true
terraform output hvn_peering_enabled              # true
terraform output hvn_peering_state                # "ACTIVE"
terraform output -json hvn_peering_hvn_route_ids       | jq 'length'   # >= 1
terraform output -json hvn_peering_aws_route_table_ids | jq 'length'   # >= 1
HVN_CIDR=$(terraform output -raw hvn_cidr)         # e.g. 172.25.16.0/20
PRIV_URL=$(terraform output -raw vault_private_endpoint_url)
```

Empty route lists mean `manage_peering_routes = false` — flip it and re-apply, or
be certain both route directions already exist by hand. `hvn_peering_state` other
than `ACTIVE` means the peering has not finished establishing; wait and re-check.

### B.2 The AWS peering and Client VPN are healthy

```shell
PCX=$(terraform output -raw aws_peering_connection_id)
VPN_EP=$(terraform output -raw vpn_endpoint_id)

aws ec2 describe-vpc-peering-connections --region "$AWS_REGION" \
  --vpc-peering-connection-ids "$PCX" \
  --query 'VpcPeeringConnections[0].Status.Code' --output text        # active

aws ec2 describe-client-vpn-endpoints --region "$AWS_REGION" \
  --client-vpn-endpoint-ids "$VPN_EP" \
  --query 'ClientVpnEndpoints[0].Status.Code' --output text           # available

aws ec2 describe-client-vpn-target-networks --region "$AWS_REGION" \
  --client-vpn-endpoint-id "$VPN_EP" \
  --query 'ClientVpnTargetNetworks[0].Status.Code' --output text      # associated

aws ec2 describe-client-vpn-routes --region "$AWS_REGION" \
  --client-vpn-endpoint-id "$VPN_EP" \
  --query "ClientVpnRoutes[?DestinationCidr=='${HVN_CIDR}'].Status.Code" --output text   # active
```

### B.3 Every managed route table carries the HVN route

```shell
for RT in $(terraform output -json hvn_peering_aws_route_table_ids | jq -r '.[]'); do
  echo "route table $RT:"
  aws ec2 describe-route-tables --region "$AWS_REGION" --route-table-ids "$RT" \
    --query "RouteTables[0].Routes[?DestinationCidrBlock=='${HVN_CIDR}'].[State, VpcPeeringConnectionId]" \
    --output text
done
# each line must read: active  <PCX>
```

### B.4 The Route53 zone is public and delegated (run with the VPN disconnected)

```shell
dig +short NS "$ZONE" @1.1.1.1       # must return Route53 nameservers (ns-*.awsdns-*)
```

This is the single most common miss for a private cluster: the cluster is
private, but the ACME DNS-01 challenge is checked by Let's Encrypt from the
**public** internet against this zone. A private or undelegated zone fails
issuance.

### B.5 Both records are live on public DNS (VPN still disconnected)

```shell
dig +short CNAME "$CNAME_FQDN"     @1.1.1.1   # => <TARGET_HOST>.
dig +short CNAME "$CHALLENGE_FQDN" @1.1.1.1   # => _acme-challenge.<TARGET_HOST>.
dig +short        "$CNAME_FQDN"    @1.1.1.1   # => an IP inside $HVN_CIDR
```

The final A record is a private HVN address published in public DNS — that is
normal; it is unreachable until the VPN is up.

### B.6 Connect the Client VPN

```shell
terraform output -raw ovpn_file_content > vault-client-vpn.ovpn
chmod 600 vault-client-vpn.ovpn
# import vault-client-vpn.ovpn into your OpenVPN client and connect

# confirm you were assigned a tunnel address from client_vpn_cidr:
ip -4 addr show 2>/dev/null | grep -E 'tun|utun' || ifconfig | grep -A2 -E 'tun|utun'
```

### B.7 Reachability WITH the VPN connected

```shell
PRIV_HOSTPORT=${PRIV_URL#https://}          # <private-host>:8200
PRIV_PORT=${PRIV_HOSTPORT##*:}

nc -zvw3 ${PRIV_HOSTPORT%:*} "$PRIV_PORT"        # succeeds
nc -zvw3 "$CNAME_FQDN"       "$PRIV_PORT"        # succeeds
curl -skS "${PRIV_URL}/v1/sys/health" | jq '{initialized, sealed, standby, version}'
# expect initialized=true, sealed=false
```

`-k` is expected: pre-enable the endpoint still serves the `*.hcp.to`
certificate, so the `vault.<zone>` SNI will not match yet.

### B.8 No reachability WITHOUT the VPN (negative check)

```shell
# disconnect the VPN, then:
nc -zvw3 ${PRIV_HOSTPORT%:*} "$PRIV_PORT"        # must time out / fail
```

If this still succeeds with the VPN down, a path to Vault exists outside this
config — understand where it comes from before you rely on the isolation.

### Section B — Go / No-Go

| Check                     | Pass criteria                                                                               | Blocks enable?                    |
|---------------------------|---------------------------------------------------------------------------------------------|-----------------------------------|
| B.1 `terraform plan`      | exit code 0                                                                                 | **yes**                           |
| B.1 outputs               | private endpoint, `vpn_enabled = true`, `hvn_peering_state = ACTIVE`, route lists non-empty | **yes**                           |
| B.2 AWS peering + VPN     | `active` / `available` / `associated` / `active`                                            | **yes**                           |
| B.3 route tables          | HVN route `active` via the `pcx-` in every managed table                                    | **yes**                           |
| B.4 zone delegation       | NS = `awsdns-*` from a public resolver                                                      | **yes**                           |
| B.5 CNAME records         | both resolve via `@1.1.1.1`                                                                 | **yes**                           |
| B.7 Vault health (VPN up) | HTTP 200, `sealed=false`                                                                    | **yes**                           |
| B.8 isolation (VPN down)  | connection times out                                                                        | no — but investigate if it passes |
| B.7 TLS                   | still the `*.hcp.to` certificate                                                            | no — expected pre-enable          |

All **yes** rows green ⇒ go to [Enable the custom domain](#enable-the-custom-domain).

---

## Enable the custom domain

Only once your section's Go / No-Go table is green. The enable call is **not**
part of this Terraform config — the full procedure (environment setup, the PATCH
request, recording the response, and waiting for the certificate workflow) is in
[Enable-Custom-Domains.md](Enable-Custom-Domains.md).

Once its operation reaches `DONE`, verify end to end with
[Test-Custom-Domains.md](Test-Custom-Domains.md): the certificate issuer should
be Let's Encrypt with `vault.<zone>` in the SAN, and a plain
`curl "https://<custom-domain>:8200/v1/sys/health"` (no `-k`) should succeed.

---