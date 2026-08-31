# Enable the custom domain

[← Back to README](../README.md)

`terraform apply` provisions the cluster, the Route53 records, and (for a private
cluster) the HVN peering and Client VPN — but it does **not** turn the custom
domain on. That is a single HCP API call, made outside this config, which tells
HCP Vault to serve the custom domain and to request a Let's Encrypt certificate
via the `_acme-challenge` record.

Run this **after** the pre-flight checklist in
[validate-custom-domain-setup-with-hvn-peering-and-vpn-only.md](validate-custom-domain-setup-with-hvn-peering-and-vpn-only.md)
is green. The procedure is the same for a public and a private cluster — the only
difference is that a private cluster's custom domain fronts the private endpoint,
so you need the Client VPN connected to reach it afterwards
([Test-Custom-Domains.md](Test-Custom-Domains.md)).

## 1. Set up the environment

Configure the shell as in [Prepare-Environment.md](Prepare-Environment.md) — AWS
credentials, `HCP_API_ADDRESS`, and a fresh `HCP_API_TOKEN`. Then add the IDs the
API call needs and read the domain values straight from Terraform:

```shell
cd terraform-fully-managed/aws

export HCP_ORGANIZATION_ID=$(hcp organizations list --format=json | jq -r '.[0].id')  # or from the HCP portal
export HCP_PROJECT_ID=<hcp_project_id from terraform.tfvars>

CLUSTER_ID=$(terraform output -raw vault_cluster_id)
CUSTOM_DOMAIN=$(terraform output -raw vault_cname_fqdn)          # vault.<zone>
AWS_REGION=<same value as aws_region in terraform.tfvars>

echo "cluster=$CLUSTER_ID  domain=$CUSTOM_DOMAIN  region=$AWS_REGION"
```

Confirm the `_acme-challenge` record is already live on public DNS — HCP's
certificate request fails without it:

```shell
dig +short CNAME "$(terraform output -raw vault_challenge_cname_fqdn)" @1.1.1.1
# => _acme-challenge.<vault_target_hostname>.
```

## 2. Fire the enable API

```shell
curl -sS -X PATCH \
  "https://${HCP_API_ADDRESS}/vault/2020-11-25/organizations/${HCP_ORGANIZATION_ID}/projects/${HCP_PROJECT_ID}/clusters/${CLUSTER_ID}" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${HCP_API_TOKEN}" \
  -d @- <<EOF | tee /tmp/enable-custom-domain.json | jq '.operation | {id, state}'
{
  "id": "${CLUSTER_ID}",
  "location": {
    "organization_id": "${HCP_ORGANIZATION_ID}",
    "project_id": "${HCP_PROJECT_ID}",
    "region": { "provider": "aws", "region": "${AWS_REGION}" }
  },
  "config": {
    "network_config": {
      "custom_domain_config": {
        "is_enabled": true,
        "custom_domain": "${CUSTOM_DOMAIN}"
      }
    }
  }
}
EOF
```

## 3. Record the response

A successful request returns an async operation, not the finished result:

```json
{
  "operation": {
    "id": "99cd338d-3f20-429d-80e0-ec8505b4c448",
    "state": "PENDING"
  }
}
```

Capture the operation ID for the next step:

```shell
export HCP_OPERATION_ID=$(jq -r '.operation.id' /tmp/enable-custom-domain.json)
echo "operation: $HCP_OPERATION_ID"
```

If the response has an `error` or an HTTP 4xx instead, nothing was changed — fix
the cause (usually the `_acme-challenge` record not resolving publicly, the
LaunchDarkly feature flag not set for the project — see
[Prerequisites.md](Prerequisites.md#you-must-add-your-project-to-the-following-ld-flags)
— or an expired `HCP_API_TOKEN`) and re-send.

## 4. Wait for the workflow to complete

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
  DNS-01 failure. Fix the record, then re-send the PATCH from step 2.

## 5. Confirm it landed

```shell
curl -sS \
  "https://${HCP_API_ADDRESS}/vault/2020-11-25/organizations/${HCP_ORGANIZATION_ID}/projects/${HCP_PROJECT_ID}/clusters/${CLUSTER_ID}" \
  -H "Authorization: Bearer ${HCP_API_TOKEN}" \
  | jq '.cluster.config.network_config.custom_domain_config, .cluster.dns_names'
```

Expect `is_enabled: true`, `custom_domain` equal to `$CUSTOM_DOMAIN`, and the
custom domain listed in `dns_names`.

## Next

- **Verify end to end:** [Test-Custom-Domains.md](Test-Custom-Domains.md) — DNS,
  reachability over the VPN, the Let's Encrypt certificate, and a Vault login on
  the custom domain.
- **Tear everything down:** [Cleanup.md](Cleanup.md).

There is no supported call to turn the custom domain off. To stop it resolving,
remove the Route53 records (`terraform destroy`, or delete them directly); to
change domains, update the `_acme-challenge` CNAME first, then re-send the step 2
PATCH with the new `custom_domain`.
