# Cleanup

[← Back to README](../README.md)

Tears down everything this configuration created. What `terraform destroy` removes
depends on which features you turned on. Resources it only read — an adopted
cluster, an adopted peering, the HVN, the VPC, the subnet — are left alone.

The custom domain has no "off" switch in the API. `terraform destroy` deletes the
DNS records, which stops the domain resolving, but the cluster keeps its
`custom_domain_config`. On a cluster this configuration created that is moot: the
whole cluster is destroyed. On an adopted cluster the setting stays until you
re-point it or delete the cluster; the issued certificate simply expires.

Capture what the later steps need before you destroy anything — the outputs go
away with the state:

```shell
cd terraform-fully-managed/aws

CUSTOM_DOMAIN=$(terraform output -raw vault_cname_fqdn)
OVPN_PATH=$(terraform output -raw ovpn_file_path 2>/dev/null || true)
HVN_CIDR=$(terraform output -raw hvn_cidr)
AWS_REGION=<same value as aws_region in terraform.tfvars>
```

## 1. Disconnect the Client VPN

Skip for a public cluster.

In your VPN client, disconnect the `vault-client-vpn` session and delete the
profile, then remove the local files:

```shell
rm -f vault-client-vpn.ovpn
[ -n "$OVPN_PATH" ] && rm -f "$OVPN_PATH"
```

## 2. Destroy the Terraform resources

```shell
terraform plan -destroy    # review before applying
terraform destroy
```

Destroyed, depending on what you enabled:

| Resource | Removed when |
|---|---|
| The `vault.<zone>` and `_acme-challenge` CNAME records | always |
| The Client VPN endpoint, its ACM certificates, and the generated `.ovpn` | `enable_vpn = true` |
| The HVN ⇄ VPC peering and its AWS-side acceptance | `create_hvn_peering = true` |
| The peering routes on both sides | a peering is managed and `manage_peering_routes = true` |
| The Vault cluster | `create_cluster = true` |
| The CloudWatch log group, IAM user, and key | `audit_log_enabled` and `cloudwatch_audit_log_enabled` both `true` |

Never touched: the HVN, the VPC and subnet, an adopted cluster or peering, and
any route you added by hand.

## 3. Adopted resources (manual)

If you adopted a peering with `existing_hvn_peering_id`, it and any routes you
added outside Terraform are still there. Remove them only if they were set up
solely for this exercise:

```shell
RT=$(aws ec2 describe-route-tables --region "$AWS_REGION" \
  --filters "Name=association.subnet-id,Values=<your subnet-id>" \
  --query 'RouteTables[0].RouteTableId' --output text)
aws ec2 delete-route --region "$AWS_REGION" --route-table-id "$RT" \
  --destination-cidr-block "$HVN_CIDR"

PCX=$(aws ec2 describe-vpc-peering-connections --region "$AWS_REGION" \
  --filters "Name=accepter-vpc-info.vpc-id,Values=<your vpc-id>" "Name=status-code,Values=active" \
  --query 'VpcPeeringConnections[0].VpcPeeringConnectionId' --output text)
aws ec2 delete-vpc-peering-connection --region "$AWS_REGION" --vpc-peering-connection-id "$PCX"
```

## 4. Adopted cluster and HVN (optional)

Only if `create_cluster = false` and you want the cluster gone. In the HCP portal,
delete the cluster (**Vault → Clusters →** the cluster **→ Manage → Delete
cluster**), then the HVN once nothing is attached to it. This also clears the
lingering `custom_domain_config`.

## 5. Reset local state

```shell
rm -rf .terraform/
rm -f  .terraform.lock.hcl   # keep if the repo commits a pinned lock
rm -f  terraform.tfstate terraform.tfstate.backup
rm -f  vault-client-vpn.ovpn
```

Restore the `REPLACE_WITH_*` placeholders in `terraform.tfvars` if you want the
shipped template back.

## Verification

```shell
dig +short CNAME "$CUSTOM_DOMAIN" @1.1.1.1
aws ec2 describe-client-vpn-endpoints --region "$AWS_REGION" \
  --filters "Name=tag:Name,Values=hcp-vault-client-vpn" \
  --query 'ClientVpnEndpoints[*].Status.Code' --output text
aws ec2 describe-route-tables --region "$AWS_REGION" \
  --filters "Name=association.subnet-id,Values=<your subnet-id>" \
  --query "RouteTables[0].Routes[?DestinationCidrBlock=='${HVN_CIDR}']" --output json
```

The CNAME query should be empty, the Client VPN list empty, and the route query
`[]`. The VPC, subnet, and HVN are untouched.
