# Terraform — Fully Managed (AWS)

Provisions the full stack for serving an HCP Vault cluster's API on a custom
domain: the cluster (created or adopted), the Route 53 records, the HVN ⇄ VPC
peering and routes, an AWS Client VPN for private clusters, and optional
audit-log streaming. Terraform completes the required configuration that 
prepares the cluster for custom domain enablement; a separate HCP API call 
turns the custom domain on and triggers certificate issuance.

## Quick start

Work through the steps in order. Each links to its own guide.

1. **Prerequisites** — line up the accounts, tools, and resources you must
   supply. See [Prerequisites.md](docs/Prerequisites.md).
2. **Environment setup** — configure AWS and HCP credentials in your shell (and,
   for remote execution, the project variable set). See
   [Prepare-Environment.md](docs/Prepare-Environment.md).
3. **Set up resources** — fill in `terraform.tfvars`, then apply:

   ```shell
   cd terraform-fully-managed/aws

   terraform init
   terraform plan     # per-variable validation, plan-time cloud checks, preconditions
   terraform apply

   # private cluster only — save the generated VPN profile locally
   terraform output -raw ovpn_file_content > vault-client-vpn.ovpn
   chmod 600 vault-client-vpn.ovpn
   ```

   An incomplete or invalid input set fails the plan before any resource is
   touched. Every input is described in [Inputs.md](docs/Inputs.md).
4. **Validate the setup** — check DNS, connectivity, and cluster health before
   enabling. See
   [Validate-Resources-Required-For-Custom-Domains.md](docs/Validate-Resources-Required-For-Custom-Domains.md).
5. **Enable the custom domain** — fire the enable API and wait for the
   certificate workflow. See [Enable-Custom-Domains.md](docs/Enable-Custom-Domains.md).
6. **Confirm the custom domain is enabled** — verify it resolves and serves Vault
   over a Let's Encrypt certificate. See [Test-Custom-Domains.md](docs/Test-Custom-Domains.md).
7. **Cleanup** — tear everything back down to state zero. See
   [Cleanup.md](docs/Cleanup.md).

## Project overview

### What it builds

- The Vault cluster — created, or an existing one adopted read-only.
- The Route 53 records: `vault.<zone>` and the `_acme-challenge` CNAME that
  Let's Encrypt validates.
- The HCP HVN ⇄ AWS VPC peering and the routes on both sides, or the adoption of
  a peering established outside this configuration.
- An AWS Client VPN with self-signed mTLS certificates, so a workstation can
  reach a private cluster over `laptop → Client VPN → VPC → peering → HVN`.
- Optional Vault audit-log streaming to CloudWatch or an external SIEM.

### Networking is a conscious choice

`public_link` decides whether a Client VPN or an HVN peering can exist at all. On
a private cluster (`public_link = false`), `enable_vpn` and `create_hvn_peering`
are separate opt-ins, and `manage_peering_routes` applies once a peering is in
play. These four variables have no default; the plan fails until each one that
applies is set. A public cluster gets no VPN or peering regardless of the other
values.

### Modules

`vault-cluster`, `vault-custom-domain-records`, `vault-hvn-peering`,
`vault-aws-client-vpn`, `cloudwatch-audit-log`, and `vault-audit-log`. See
[Modules.md](docs/Modules.md) for what each one does.

### Inputs and outputs

Inputs, their defaults, the validation rules, and the networking-enablement
matrix are in [Inputs.md](docs/Inputs.md). Every `terraform output` and what it
means is in [Outputs.md](docs/Outputs.md).

### Further reading

[Optional-Reading.md](docs/Optional-Reading.md) covers the module wiring diagram
and the full audit-logging control model.
