# Authenticates through `az login` locally, or the ARM_* environment variables
# on the HCP Terraform workspace (see backend.tf).
provider "azurerm" {
  subscription_id = var.subscription_id

  features {}
}

# Used only by the dns-zones module to write the NS delegation records into the
# existing Route 53 zones. Route 53 is global; the region only satisfies the
# provider. Authenticate with your usual AWS credentials (Doormat) or the
# AWS_* environment variables on the HCP Terraform workspace.
provider "aws" {
  region = var.aws_region
}
