###############################################################################
# Terraform state backend: HCP Terraform workspace
#
# TODO(you): replace BOTH placeholders below with your HCP Terraform
# organization and workspace name. Terraform parses this block before it
# evaluates variables, so the values must be literals here (or be supplied at
# `terraform init` via the TF_CLOUD_ORGANIZATION and TF_WORKSPACE environment
# variables, in which case keep an empty `cloud {}` block).
#
# Azure credentials: a remote run has no `az login` session. Either set the
# workspace's execution mode to "Local" (state stays in HCP Terraform, the run
# uses your `az login`), or keep it "Remote" and set ARM_CLIENT_ID,
# ARM_CLIENT_SECRET, ARM_TENANT_ID and ARM_SUBSCRIPTION_ID on the workspace.
###############################################################################

terraform {
  cloud {
    organization = "<TODO-your-hcp-terraform-organization>"

    workspaces {
      name = "<TODO-your-hcp-terraform-workspace>"
    }
  }
}
