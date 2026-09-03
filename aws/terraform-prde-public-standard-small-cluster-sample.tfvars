# Minimal Terraform variable values required for creating public cluster and CNAME records
# In the Route53 Hosted Zone (sujay-samanta.sbx.hashidemos.io )

aws_region               = "us-west-2"
hcp_project_id           = "aee0a454-5fca-4356-b72e-2897f285bce4"
hcp_organization_id      = "6a8ce940-6b08-43e8-9329-3ab02e494ea8"
route53_hosted_zone_name = "sujay-samanta.sbx.hashidemos.io"
vault_record_name        = "vault"
cluster_id               = "1-prde-cluster-03-sep"
create_cluster           = true
hvn_id                   = "aws-secondary"
public_link              = true
vault_tier               = "STANDARD_SMALL"





