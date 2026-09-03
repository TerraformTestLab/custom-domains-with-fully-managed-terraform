# Prepare Environment

[← Back to README](../README.md)

Set these before you run any Terraform command or call the custom-domain API.
The values shown are for the `int` environment; for others take them from the
[environments reference](https://github.com/hashicorp/cloud-experiences-tooling-docs/blob/main/docs/go-sdk/environments.md#environments).

## HCP Environment Variables

```shell
# Endpoints (int)
export HCP_AUTH_URL="https://auth.idp.hcp.to"
export HCP_API_ADDRESS="api.hcp.to"
export HCP_API_HOST="api.hcp.to"
export HCP_OAUTH_CLIENT_ID="93d16cef-8432-4499-a764-7a5c04725894"

# Project identifiers — must match terraform.tfvars
export HCP_ORGANIZATION_ID="<hcp_organization_id>"
export HCP_PROJECT_ID="<hcp_project_id>"
export HCP_PROVIDER_NAME="aws"

# Service principal for the hcp Terraform provider
export HCP_CLIENT_ID="<service-principal client ID>"
export HCP_CLIENT_SECRET="<service-principal client secret>"

# Short-lived bearer token for direct HCP API calls
hcp auth logout
hcp auth login
export HCP_API_TOKEN="$(hcp auth print-access-token)"
```

- `HCP_CLIENT_ID` / `HCP_CLIENT_SECRET` authenticate the `hcp` provider and are
  required for every `terraform init`, `plan`, and `apply`. The service principal
  needs **Contributor** on the project's Vault service (see
  [Prerequisites.md](Prerequisites.md)). `HCP_API_HOST` is the provider's own
  copy of `HCP_API_ADDRESS`.
- `HCP_API_TOKEN` is short-lived — re-run the last three lines when a call
  returns `401`.
- `HCP_ORGANIZATION_ID`, `HCP_PROJECT_ID`, and `HCP_PROVIDER_NAME` are used by
  the custom-domain API calls in
  [Enable-Custom-Domains.md](Enable-Custom-Domains.md) and
  [Test-Custom-Domains.md](Test-Custom-Domains.md). `HCP_ORGANIZATION_ID` must
  equal `hcp_organization_id` in `terraform.tfvars`.
- For a **private cluster with `manage_peering_routes = true`**, `terraform plan`
  reads the HVN's routes from the HCP API. The root configuration injects
  `HCP_API_TOKEN` and `HCP_API_ADDRESS` from your shell into the
  `vault-hvn-peering` module, so both must be current before `terraform plan`.

## AWS Environment Variables

Always required. Copy fresh values from **Doormat → Individual AWS Accounts →
your sandbox account → CLI → Copy to clipboard**:

```shell
export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
export AWS_SESSION_TOKEN="IQoJb3JpZ2luX2VjEXAMPLE...<truncated-for-brevity>"
```

These are temporary, per-session credentials. Never commit them, reuse them
across sessions, or paste them into chat tools or tickets.

## Remote execution on HCP Terraform

Skip this section for local runs.

With remote execution, `terraform init`, `plan`, and `apply` run on HCP
Terraform's servers, so the credentials must also exist as **workspace
environment variables** — directly on the workspace or on a variable set applied
to it. Set:

| Variable                                                          | Value                 |
|-------------------------------------------------------------------|-----------------------|
| `HCP_CLIENT_ID`, `HCP_CLIENT_SECRET`                              | service principal key |
| `HCP_API_HOST`, `HCP_AUTH_URL`, `HCP_OAUTH_CLIENT_ID`             | endpoints, as above   |
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` | sandbox credentials   |

Mark every secret (`HCP_CLIENT_SECRET`, `AWS_SECRET_ACCESS_KEY`,
`AWS_SESSION_TOKEN`) as sensitive.

### Managing AWS credentials with Doormat

AWS sandbox credentials expire, so rather than re-pasting them, let Doormat push
fresh values into a variable set and apply that set to the workspace:

```shell
export AWS_ACCOUNT_ID="123456789012"   # your sandbox account ID
doormat aws tf-push variable-set --id <your-varset-id> -a "${AWS_ACCOUNT_ID}"
```

`doormat aws tf-push` writes `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and
`AWS_SESSION_TOKEN` into the named variable set. Confirm the set is attached to
the workspace under **Settings → Variable sets** — credentials in an unattached
set never reach the run.

## Checklist

- [ ] HCP endpoints (`HCP_AUTH_URL`, `HCP_API_ADDRESS`, `HCP_API_HOST`,
      `HCP_OAUTH_CLIENT_ID`) exported
- [ ] `HCP_ORGANIZATION_ID`, `HCP_PROJECT_ID`, `HCP_PROVIDER_NAME` exported
- [ ] `HCP_CLIENT_ID` / `HCP_CLIENT_SECRET` exported (service principal with
      Contributor on Vault)
- [ ] `hcp auth login` done and `HCP_API_TOKEN` current
- [ ] AWS credentials exported
- [ ] Private cluster with `manage_peering_routes = true`: `hcp_organization_id`
      set in `terraform.tfvars`, `HCP_API_TOKEN` and `HCP_API_ADDRESS` current
- [ ] Remote execution only: the HCP and AWS variables above set on the workspace
      (or an applied variable set)
