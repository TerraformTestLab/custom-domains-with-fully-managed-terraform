# Cleanup — reset to state zero

[← Back to README](../README.md)

Tears down everything this config created. What `terraform destroy` removes
depends on what you turned on — a public cluster has no VPN or peering to destroy;
an adopted cluster or an adopted peering is never destroyed because this config
only reads it.

> **The custom domain cannot be turned off through the API.** There is no
> supported "disable" call. `terraform destroy` deletes the `vault.<zone>` and
> `_acme-challenge` records, which makes the domain stop resolving and stop
> working — but the cluster's `custom_domain_config` stays as it is. On a cluster
> **this config created** that is moot (the whole cluster is destroyed). On an
> **adopted** cluster the config lingers, inert, until you re-point it by
> re-applying, or delete the cluster. The already-issued Let's Encrypt
> certificate simply expires (~90 days).

Capture the values the later steps need **before** you destroy anything — the
outputs disappear with the state:

```shell
cd terraform-fully-managed/aws

CUSTOM_DOMAIN=$(terraform output -raw vault_cname_fqdn)
OVPN_PATH=$(terraform output -raw ovpn_file_path 2>/dev/null || true)
PEERING_ADOPTED=$(terraform output -raw hvn_peering_adopted 2>/dev/null || echo "null")
HVN_CIDR=$(terraform output -raw hvn_cidr)
AWS_REGION=<same value as aws_region in terraform.tfvars>
```

## 1. Disconnect and remove the Client VPN profile

Skip for a public cluster.

1. In your VPN client (Tunnelblick / OpenVPN Connect / AWS VPN Client),
   **disconnect** the `vault-client-vpn` session and **delete the configuration**.
2. Remove the local profile files:

   ```shell
   rm -f vault-client-vpn.ovpn
   [ -n "$OVPN_PATH" ] && rm -f "$OVPN_PATH"
   ```

## 2. Destroy the Terraform-managed infrastructure

```shell
terraform plan -destroy    # review — nothing outside this list should be affected
terraform destroy
```

| Removed by `terraform destroy` | Only when |
|---|---|
| Route53 `vault.<zone>` CNAME and `_acme-challenge.vault.<zone>` CNAME | always |
| Self-signed CA + server/client certs, both ACM imports | `enable_vpn = true` |
| Client VPN endpoint, subnet association, authorization rules, HVN route, generated `.ovpn` | `enable_vpn = true` |
| `hcp_aws_network_peering` + the AWS `aws_vpc_peering_connection_accepter` | `create_hvn_peering = true` |
| `hcp_hvn_route` (VPC CIDR) and `aws_route` (HVN CIDR) | a peering is managed **and** `manage_peering_routes = true` |
| `hcp_vault_cluster` | `create_cluster = true` |
| CloudWatch log group, IAM user, access key, policy | `audit_log_enabled = true` and `cloudwatch_audit_log_enabled = true` |

| **Never touched** | Why |
|---|---|
| The HVN | read-only (`data.hcp_hvn`) — this config never creates or deletes it |
| An **adopted** peering (`existing_hvn_peering_id` set) | read-only data source — see step 3 |
| An **adopted** cluster (`create_cluster = false`) | read-only data source; its `custom_domain_config` is left as-is (see the note above) |
| The VPC and subnet | supplied by you, read-only here |
| Route tables themselves, and any route you added by hand | only the routes this config wrote are removed |

## 3. Adopted resources (manual, only if you want a true zero)

If you ran with `create_hvn_peering = false` and an `existing_hvn_peering_id`, the
peering and any routes you added outside Terraform are still there. Remove them
only if they were stood up solely for this exercise.

```shell
# the route you added by hand to the subnet's route table, if any
RT=$(aws ec2 describe-route-tables --region "$AWS_REGION" \
  --filters "Name=association.subnet-id,Values=<your subnet-id>" \
  --query 'RouteTables[0].RouteTableId' --output text)
aws ec2 delete-route --region "$AWS_REGION" --route-table-id "$RT" \
  --destination-cidr-block "$HVN_CIDR"

# the adopted peering (deletes it on the AWS side; also clears it in the HCP portal)
PCX=$(aws ec2 describe-vpc-peering-connections --region "$AWS_REGION" \
  --filters "Name=accepter-vpc-info.vpc-id,Values=<your vpc-id>" "Name=status-code,Values=active" \
  --query 'VpcPeeringConnections[0].VpcPeeringConnectionId' --output text)
aws ec2 delete-vpc-peering-connection --region "$AWS_REGION" --vpc-peering-connection-id "$PCX"
```

`PEERING_ADOPTED` (captured at the top) is `true` when this applies, `false` when
Terraform created and therefore already destroyed the peering, `null` when there
was no peering.

## 4. Optional — delete an adopted cluster and the HVN

Only if `create_cluster = false` (Terraform did not create the cluster) and you
want it gone — this also disposes of the lingering `custom_domain_config`. Via the
HCP portal:

1. **Vault → Clusters →** your cluster **→ Manage → Delete cluster**; type the
   name to confirm.
2. **HVN →** your HVN **→ Delete** — possible only after every cluster and peering
   attached to it is gone.

## 5. Reset local state

```shell
rm -rf .terraform/
rm -f  .terraform.lock.hcl          # keep this if the repo commits a pinned lock
rm -f  terraform.tfstate terraform.tfstate.backup
rm -f  vault-client-vpn.ovpn
```

`terraform.tfvars` still holds your deployment values — restore the
`REPLACE_WITH_*` placeholders and blank the networking booleans if you want the
shipped template back.

## Verification

```shell
echo "=== CNAME gone ==="        && dig +short CNAME "$CUSTOM_DOMAIN" @1.1.1.1
echo "=== Client VPN gone ==="   && aws ec2 describe-client-vpn-endpoints --region "$AWS_REGION" \
  --filters "Name=tag:Name,Values=hcp-vault-client-vpn" \
  --query 'ClientVpnEndpoints[*].Status.Code' --output text
echo "=== HVN route gone ==="    && aws ec2 describe-route-tables --region "$AWS_REGION" \
  --filters "Name=association.subnet-id,Values=<your subnet-id>" \
  --query "RouteTables[0].Routes[?DestinationCidrBlock=='${HVN_CIDR}']" --output json
```

Expected: the CNAME query is empty, the Client VPN status list is empty, and the
route query returns `[]`. The VPC, subnet, and HVN are untouched.
