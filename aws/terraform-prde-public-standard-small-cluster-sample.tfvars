# Minimal Terraform variable values required for creating public cluster and CNAME records
# In the Route53 Hosted Zone (sujay-samanta.sbx.hashidemos.io )

aws_region               = "" # Specify the AWS region for the cluster your cluster's HVN region should match e.g: "us-west-2"
hcp_project_id           = "" # Specify the HCP project ID for the cluster where the Vault cluster will be created e.g: "c1ec9da6-6ab9-4f27-bbab-97b7bf2ed9f5"
hcp_organization_id      = "" # Specify the HCP organization ID for the cluster where the Vault cluster will be created e.g: "0286a7c3-6331-4dab-8aab-ca2a94994cd2"
route53_hosted_zone_name = "" # Specify the Route53 Hosted Zone name e.g: "sujay-samanta.sbx.hashidemos.io"
vault_record_name        = "vault" # Specify the DNS record name for the Vault cluster within the Route53 Hosted Zone must be vault
cluster_id               = "" # Specify the cluster ID for the Vault cluster within the HCP project e.g: "1-prde-cluster-03-sep"
create_cluster           = false # Specify whether to create the Vault cluster within the HCP project set this to false if the cluster already exists
hvn_id                   = "" # Specify the HVN ID for the cluster within the HCP project e.g: "aws-secondary"
public_link              = true # Specify whether the Vault cluster should be accessible via a public link set this to false for private-only access
vault_tier               = "" # Specify the Vault cluster tier within the HCP project e.g: "STANDARD_SMALL"





