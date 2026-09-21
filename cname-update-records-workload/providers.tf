# Each provider is only used when its cloud is listed in
# hosted_zone_cloud_provider; the matching module is skipped otherwise.

# The subscription and credentials come from the ARM_* environment variables on
# the HCP Terraform workspace (see backend.tf).
provider "azurerm" {
  features {}
}

# Route 53 is global; the region only satisfies the provider.
provider "aws" {
  region = var.aws_region
}
