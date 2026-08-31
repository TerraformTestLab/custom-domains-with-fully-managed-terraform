# Enable the custom domain

[← Back to README](../README.md)

`terraform apply` provisions the cluster, the Route53 records, and (for a private
cluster) the HVN peering and Client VPN — but it does **not** turn the custom
domain on. That is a single HCP API call, made outside this config, which tells
HCP Vault to serve the custom domain and to request a Let's Encrypt certificate
via the `_acme-challenge` record.

Run this **after** the pre-flight checklist in
[Validate-Resources-Required-For-Custom-Domains.md](Validate-Resources-Required-For-Custom-Domains.md)
is green. The procedure is the same for a public and a private cluster — the only
difference is that a private cluster's custom domain fronts the private endpoint,
so you need the Client VPN connected to reach it afterwards
([Test-Custom-Domains.md](Test-Custom-Domains.md)).

## 1. Set up the environment

Same variables as [`guides/test-custom-domain.sh`](../../../guides/test-custom-domain.sh),
plus your AWS credentials (see [Prepare-Environment.md](Prepare-Environment.md)).
The static HCP endpoints below are the `int` environment — for other environments
take them from [Prepare-Environment.md](Prepare-Environment.md).

```shell
cd terraform-fully-managed/aws

# static HCP endpoints (int environment)
export HCP_AUTH_URL="https://auth.idp.hcp.to"
export HCP_API_ADDRESS="api.hcp.to"
export HCP_OAUTH_CLIENT_ID="93d16cef-8432-4499-a764-7a5c04725894"

# identifiers the PATCH call needs
export HCP_ORGANIZATION_ID="<your HCP org ID — HCP portal → Settings>"
export HCP_PROJECT_ID="<hcp_project_id from terraform.tfvars>"
export HCP_PROVIDER_NAME="aws"
export HCP_REGION_NAME="<same value as aws_region in terraform.tfvars>"
export HCP_VAULT_ID="$(terraform output -raw vault_cluster_id)"
export HCP_CUSTOM_DOMAIN="$(terraform output -raw vault_cname_fqdn)"   # vault.<zone>

echo "cluster=$HCP_VAULT_ID  domain=$HCP_CUSTOM_DOMAIN  region=$HCP_REGION_NAME"
```

Confirm the `_acme-challenge` record is already live on public DNS — HCP's
certificate request fails without it:

```shell
dig +short CNAME "$(terraform output -raw vault_challenge_cname_fqdn)" @1.1.1.1
# => _acme-challenge.<vault_target_hostname>.
```

## 2. Re-authenticate to HCP

Do this **immediately before** step 3 — the access token is short-lived, and a
stale one is the most common reason the PATCH (or the polling) comes back `401`.

```shell
hcp auth logout
hcp auth login
export HCP_API_TOKEN="$(hcp auth print-access-token)"
```

Re-run this block any time a later call returns `401`.

## 3. Fire the enable API

```shell
curl -sS -X PATCH \
  "https://${HCP_API_ADDRESS}/vault/2020-11-25/organizations/${HCP_ORGANIZATION_ID}/projects/${HCP_PROJECT_ID}/clusters/${HCP_VAULT_ID}" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${HCP_API_TOKEN}" \
  -d @- <<EOF | tee enable-custom-domain-response.json | jq '.operation | {id, state}'
{
  "id": "${HCP_VAULT_ID}",
  "location": {
    "organization_id": "${HCP_ORGANIZATION_ID}",
    "project_id": "${HCP_PROJECT_ID}",
    "region": { "provider": "${HCP_PROVIDER_NAME}", "region": "${HCP_REGION_NAME}" }
  },
  "config": {
    "network_config": {
      "custom_domain_config": {
        "is_enabled": true,
        "custom_domain": "${HCP_CUSTOM_DOMAIN}"
      }
    }
  }
}
EOF
```

The full response is written to `enable-custom-domain-response.json` in the
working directory. A successful request returns an async **operation** in state
`PENDING` — not the finished result. If instead it returns an `error` or an HTTP
4xx, nothing was changed: fix the cause (usually the `_acme-challenge` record not
resolving publicly, the LaunchDarkly feature flag not set for the project — see
[Prerequisites.md](Prerequisites.md#launchdarkly-flags)
— or a stale token: re-run step 2) and fire again.

## Next

- **Verify end to end:** [Test-Custom-Domains.md](Test-Custom-Domains.md) — DNS,
  reachability over the VPN, the Let's Encrypt certificate, and a Vault login on
  the custom domain.
- **Tear everything down:** [Cleanup.md](Cleanup.md).

There is no supported call to turn the custom domain off. To stop it resolving,
remove the Route53 records (`terraform destroy`, or delete them directly); to
change domains, update the `_acme-challenge` CNAME first, then re-send the step 3
PATCH with the new `custom_domain`.

---

## Track the certificate workflow (optional)

The PATCH in step 3 returns as soon as the operation is queued. These steps let
you watch it finish and confirm the result — do them whenever it suits you. The
custom domain does not actually serve traffic until the operation reaches `DONE`.

### A. Record the response

`enable-custom-domain-response.json` holds the full operation object:

```json
{
  "operation": {
    "id": "99cd338d-3f20-429d-80e0-ec8505b4c448",
    "state": "PENDING"
  }
}
```

```shell
export HCP_OPERATION_ID=$(jq -r '.operation.id' enable-custom-domain-response.json)
echo "operation: $HCP_OPERATION_ID"
```

### B. Wait for the workflow to complete

The operation moves `PENDING` → `RUNNING` → `DONE`. It usually finishes in a few
minutes; DNS propagation of the ACME record can stretch it out.

```shell
watch -n 15 "curl -sS \
  'https://${HCP_API_ADDRESS}/resource-manager/2019-12-10/organizations/${HCP_ORGANIZATION_ID}/projects/${HCP_PROJECT_ID}/operations/${HCP_OPERATION_ID}' \
  -H 'Authorization: Bearer \$(hcp auth print-access-token)' \
  | jq '.operation | {state, error}'"
```

- `state: DONE` with `error: null` → the cluster is serving the custom-domain
  certificate.
- `state: RUNNING` for a long time → check the `_acme-challenge` record resolves
  from a public resolver (`dig +short CNAME <challenge_fqdn> @8.8.8.8`); Let's
  Encrypt validates it over the public internet.
- `state` with a non-null `error` → read the message; the most common is a
  DNS-01 failure. Fix the record, then re-send the PATCH from step 3.

### C. Confirm it landed

```shell
curl -sS \
  "https://${HCP_API_ADDRESS}/vault/2020-11-25/organizations/${HCP_ORGANIZATION_ID}/projects/${HCP_PROJECT_ID}/clusters/${HCP_VAULT_ID}" \
  -H "Authorization: Bearer $(hcp auth print-access-token)" \
  | jq '.cluster.config.network_config.custom_domain_config, .cluster.dns_names'
```

Expect `is_enabled: true`, `custom_domain` equal to `$HCP_CUSTOM_DOMAIN`, and the
custom domain listed in `dns_names`.
