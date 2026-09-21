###############################################################################
# Terraform state backend and REMOTE execution: HCP Terraform workspace
#
# This config is meant to run remotely, so plan and apply execute on HCP
# Terraform, not on your machine. Complete the TODOs below before `terraform init`.
#
# TODO(you) 1: replace BOTH placeholders below with your HCP Terraform
#   organization and workspace name. Terraform parses this block before it
#   evaluates variables, so the values must be literals here (or be supplied at
#   `terraform init` via the TF_CLOUD_ORGANIZATION and TF_WORKSPACE environment
#   variables, in which case keep an empty `cloud {}` block).
#
# TODO(you) 2: in the workspace, Settings -> General -> Execution Mode, choose
#   "Remote". A remote run has no `az login` or local AWS session, so it needs
#   the credentials in TODOs 3 and 4.
#
# TODO(you) 3: only if you update AWS records - add these as ENVIRONMENT
#   variables on the workspace (mark them sensitive):
#     AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_SESSION_TOKEN if your
#     credentials are temporary (they expire, so refresh them before each run).
#
# TODO(you) 4: only if you update Azure records - add these as ENVIRONMENT
#   variables on the workspace (mark them sensitive):
#     ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID and ARM_SUBSCRIPTION_ID
#   for a service principal that can write DNS records in the target zones (for
#   example DNS Zone Contributor on the DNS resource group).
#
# TODO(you) 5: run with one of the cname-update-records-*.tfvars files:
#     terraform plan  -var-file=<file>.tfvars
#     terraform apply -var-file=<file>.tfvars
###############################################################################

terraform {
  cloud {
    organization = "<TODO-your-hcp-terraform-organization>"

    workspaces {
      name = "<TODO-your-hcp-terraform-workspace>"
    }
  }
}
