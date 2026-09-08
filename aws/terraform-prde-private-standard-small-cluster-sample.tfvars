# Minimal Terraform variable values required for creating public cluster and CNAME records
# In the Route53 Hosted Zone (sujay-samanta.aws.sbx.hashicorpdemo.com) https://us-east-1.console.aws.amazon.com/route53/v2/hostedzones?region=us-west-2#ListRecordSets/X9664279R1ZLSL5SEKX1
# SANDBOX VPC https://us-west-2.console.aws.amazon.com/vpcconsole/home?region=us-west-2#VpcDetails:VpcId=vpc-0z1bgvy2hsl3c2792
# SANDBOX VPC SUBNET https://us-west-2.console.aws.amazon.com/vpcconsole/home?region=us-west-2#SubnetDetails:subnetId=subnet-5z6mj9l51q3646k66

aws_region               = "" # AWS region for the resources should match the region of your HVN where the cluster is or will be created, e.g., "us-west-2"
client_vpn_cidr          = "" # CIDR block for the client VPN, e.g., "10.200.0.0/22"
cluster_id               = "" # Cluster ID for the Vault cluster, e.g., "2-prde-cluster-04-sep"
create_cluster           = false # Whether to create the Vault cluster, e.g., true or false, set it to false if the cluster already exists
create_hvn_peering       = false # Whether to create peering between the Vault cluster's HVN and your VPC, e.g., true or false set it to false if the peering already exists or you don't want it manged by Terraform
enable_vpn               = false # Whether to enable the client VPN, e.g., true or false set it to false if you have other networking solutions in place to reach your private cluster
hcp_organization_id      = "" # HCP organization ID in where the Vault cluster will be created, e.g., "794c217f-6390-43de-94aa-b2961bc8fe2c"
hcp_project_id           = "" # HCP project ID in where the Vault cluster will be created, e.g., "effba6e1-81de-4293-879c-db909ceb68c9"
hvn_id                   = "" # HVN ID of the Vault cluster, e.g., "aws-secondary"
manage_peering_routes    = false # Whether to manage peering routes between the Vault cluster's HVN and your VPC, e.g., true or false, set it to false if you want to manage them manually
min_vault_version        = "v1.21.3" # Optional minimum Vault version for the cluster
public_link              = false # Whether to enable the public link for the Vault cluster, e.g., true or false, must be set to false for private-only cluster
route53_hosted_zone_name = "" # Route53 hosted zone name for the Vault cluster, e.g., "sujay-samanta.aws.sbx.hashicorpdemo.com"
subnet_id                = "" # Subnet ID for the Vault cluster, e.g., "lzvyjj-7o3eq2n29w0393p41"
vault_record_name        = "vault" # DNS record name for the Vault cluster within the Route53 hosted zone must be vault
vault_tier               = "" # Vault tier for the cluster, e.g., "STANDARD_SMALL"
vpc_id                   = "" # VPC ID for the Vault cluster, e.g., "opa-1l8kkwu9ejp8y3976"
