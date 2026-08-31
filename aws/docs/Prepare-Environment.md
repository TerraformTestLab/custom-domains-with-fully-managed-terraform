# Prepare Environment

[← Back to README](../README.md)

Configure your shell before running `terraform init`, `plan`, and `apply` from
the Deploy section of the README. The exact values depend on two things:

- **environment** — `int`, `prod`, … (the samples below are `int`)
- **execution mode** — Terraform running locally vs. HCP Terraform remote execution

## HCP Authentication

Set the three static, environment-specific vars, re-authenticate, then derive a
fresh token. The values below are the `int` environment — for other environments
take them from the canonical
[environments reference](https://github.com/hashicorp/cloud-experiences-tooling-docs/blob/main/docs/go-sdk/environments.md#environments).

```shell
export HCP_AUTH_URL="https://auth.idp.hcp.to"
export HCP_API_ADDRESS="api.hcp.to"
export HCP_OAUTH_CLIENT_ID="93d16cef-8432-4499-a764-7a5c04725894"

hcp auth logout
hcp auth login

export HCP_API_TOKEN="$(hcp auth print-access-token)"
```

`HCP_API_TOKEN` is short-lived — re-run the last line whenever it expires.

## AWS Credentials — Local Execution

Needed only when Terraform runs locally, or when execution is local against a
remote/cloud backend. Pull fresh values from **Doormat → Individual AWS Accounts →
[your sandbox account row] → CLI → Copy to clipboard**, then export them:

```shell
export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
export AWS_SESSION_TOKEN="IQoJb3JpZ2luX2VjEXAMPLE...<truncated-for-brevity>"
```

These are temporary, per-session credentials. Never commit them, never reuse them
across sessions, and never paste them into chat tools or tickets.

## AWS Credentials — Remote Execution (HCP Terraform)

If the run uses HCP Terraform remote execution, skip the local section above.
Instead, push credentials into the project's HCP Terraform variable set through
**Doormat**: by running `doormat aws tf-push variable-set --id <YOUR-VARSET-ID> -a ${AWS_ACCOUNT_ID}`

```shell
export AWS_ACCOUNT_ID="123456789012" # you can save this in you .zshrc or .bashrc
doormat aws tf-push variable-set --id varset-xvfRyT1qNahGfpWm -a ${AWS_ACCOUNT_ID}
```

`AWS_ACCOUNT_ID` is not defined in the README — set it to your own sandbox
account id before running the push.

## Quick-reference checklist

- [ ] HCP auth vars set and logged in
- [ ] `HCP_API_TOKEN` refreshed
- [ ] AWS creds set (local only) **or** variable set pushed (remote only)
