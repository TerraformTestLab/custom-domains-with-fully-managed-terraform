# Prepare Environment

[← Back to README](../README.md)

Configure your shell before you run anything in the quick start. The values below
are the `int` environment; for other environments take them from the
[environments reference](https://github.com/hashicorp/cloud-experiences-tooling-docs/blob/main/docs/go-sdk/environments.md#environments).

## HCP authentication

Set the static endpoints and the cluster identifiers, re-authenticate, then
export a fresh token.

```shell
export HCP_AUTH_URL="https://auth.idp.hcp.to"
export HCP_API_ADDRESS="api.hcp.to"
export HCP_OAUTH_CLIENT_ID="93d16cef-8432-4499-a764-7a5c04725894"

export HCP_ORGANIZATION_ID="<hcp_organization_id from terraform.tfvars — HCP portal → Settings>"
export HCP_PROJECT_ID="<hcp_project_id from terraform.tfvars>"
export HCP_PROVIDER_NAME="aws"

hcp auth logout
hcp auth login
export HCP_API_TOKEN="$(hcp auth print-access-token)"
```

`HCP_API_TOKEN` is short-lived. Re-run the last three lines when a call returns
`401`.

`HCP_ORGANIZATION_ID`, `HCP_PROJECT_ID`, and `HCP_PROVIDER_NAME` are used by the
custom-domain API calls in [Enable-Custom-Domains.md](Enable-Custom-Domains.md)
and [Test-Custom-Domains.md](Test-Custom-Domains.md). `HCP_ORGANIZATION_ID` must
match `hcp_organization_id` in `terraform.tfvars`.

For a **private cluster with `manage_peering_routes = true`**, `terraform plan`
itself reads the HVN's existing routes from the HCP API. That plan will fail
unless `hcp_organization_id` is set in `terraform.tfvars` and `HCP_API_TOKEN` is
current in your shell.

## AWS credentials

Always required. Copy fresh values from **Doormat → Individual AWS Accounts →
your sandbox account → CLI → Copy to clipboard**, then export them:

```shell
export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
export AWS_SESSION_TOKEN="IQoJb3JpZ2luX2VjEXAMPLE...<truncated-for-brevity>"
```

These are temporary, per-session credentials. Never commit them, reuse them
across sessions, or paste them into chat tools or tickets.

## AWS credentials for remote execution

With HCP Terraform remote execution, the credentials must also be on the HCP
Terraform side, or `terraform init`, `plan`, and `apply` cannot run on HCP's
servers. Push them into the project's variable set through Doormat:

```shell
export AWS_ACCOUNT_ID="123456789012"   # your sandbox account ID
doormat aws tf-push variable-set --id <your-varset-id> -a "${AWS_ACCOUNT_ID}"
```

## Checklist

- [ ] HCP endpoints set and `hcp auth login` done
- [ ] `HCP_ORGANIZATION_ID`, `HCP_PROJECT_ID`, `HCP_PROVIDER_NAME` exported
- [ ] `HCP_API_TOKEN` exported and current
- [ ] AWS credentials exported in your shell
- [ ] Private cluster with `manage_peering_routes = true`: `hcp_organization_id`
      set in `terraform.tfvars`
- [ ] Remote execution only: AWS credentials pushed to the project variable set
