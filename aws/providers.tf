provider "aws" {
  region = var.aws_region
}

# Authenticate with an HCP service principal by setting HCP_CLIENT_ID and
# HCP_CLIENT_SECRET on the HCP Terraform workspace (or in the local environment
# for local runs).
provider "hcp" {
  project_id = var.hcp_project_id
}
