###############################################################################
# Terraform state backend
#
# DEFAULT: local backend - state is written to ./terraform.tfstate in this
# directory. No configuration needed; fine for a single operator or a demo.
#
# OPTIONAL: HCP Terraform (remote state + runs + stored variables). Uncomment
# the block below and set your organization and workspace.
#
# Why this is hard-coded and not a variable: Terraform parses the `terraform` /
# `cloud` / `backend` block BEFORE it evaluates variables, so it cannot read
# var.* or terraform.tfvars. The two values must be literals here - or supplied
# at `terraform init` time via the TF_CLOUD_ORGANIZATION and TF_WORKSPACE
# environment variables, in which case keep an empty `cloud {}` block and drop
# the two attributes.
#
# Set BOTH organization and workspaces.name, or neither - a `cloud` block with
# only one is invalid.
###############################################################################

# terraform {
#   cloud {
#     # HCP Terraform org: app.terraform.io -> your org -> Settings ->
#     # "Organization Settings" (also the /app/<org>/ segment of the URL).
#     organization = "sujay-test-01"
#
#     workspaces {
#       # Workspace that holds THIS configuration's state. Use one distinct from
#       # the repo-root ./ config so the two state files never collide. Create it
#       # (CLI-driven workflow) before the first `terraform init`.
#       name = "vault-custom-domains-fully-managed-with-aws"
#     }
#   }
# }
