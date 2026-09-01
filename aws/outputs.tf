# Vault cluster outputs
output "vault_cluster_id" {
  description = "ID of the HCP Vault cluster."
  value       = module.vault_cluster.cluster_id
}

output "vault_cluster_created" {
  description = "Whether Terraform created the cluster (false means an existing one was adopted)."
  value       = module.vault_cluster.cluster_created
}

output "vault_cluster_tier" {
  description = "Tier of the HCP Vault cluster."
  value       = module.vault_cluster.tier
}

output "vault_version" {
  description = "Running Vault version of the cluster."
  value       = module.vault_cluster.vault_version
}

output "vault_private_endpoint_url" {
  description = "Private endpoint URL of the Vault cluster."
  value       = module.vault_cluster.vault_private_endpoint_url
}

output "vault_public_endpoint_url" {
  description = "Public endpoint URL of the Vault cluster (empty when public_link is false)."
  value       = module.vault_cluster.vault_public_endpoint_url
}

output "vault_target_hostname" {
  description = "Bare hostname the custom domain CNAME points at (public host when public_link, else private)."
  value       = local.vault_target_hostname
}

output "audit_log_enabled" {
  description = "Whether any Vault audit-log streaming is active."
  value       = module.cloudwatch_audit_log.enabled || module.vault_audit_log.enabled
}

output "audit_log_destination" {
  description = "Active audit-log destination: \"cloudwatch\" (AWS-native module), the external sink name, or \"\"."
  value       = module.cloudwatch_audit_log.enabled ? "cloudwatch" : module.vault_audit_log.destination
}

output "audit_log_cloudwatch_group_name" {
  description = "CloudWatch log group receiving the audit stream (null unless the AWS-native module is enabled)."
  value       = module.cloudwatch_audit_log.log_group_name
}

output "audit_log_cloudwatch_iam_user" {
  description = "Dedicated IAM user HCP uses to write to CloudWatch (null unless the AWS-native module is enabled)."
  value       = module.cloudwatch_audit_log.iam_user_name
}

output "vault_cname_fqdn" {
  description = "FQDN of the Vault CNAME record."
  value       = module.vault_custom_domain_records.vault_cname_fqdn
}

output "vault_challenge_cname_fqdn" {
  description = "FQDN of the ACME challenge CNAME record."
  value       = module.vault_custom_domain_records.vault_challenge_cname_fqdn
}

output "is_private_endpoint" {
  description = "Whether the cluster is targeted via its private endpoint (public_link = false)."
  value       = local.is_private_endpoint
}

output "is_public_endpoint" {
  description = "Whether the cluster is targeted via its public endpoint (public_link = true)."
  value       = local.is_public_endpoint
}

output "hvn_cidr" {
  description = "IPv4 CIDR of the HVN, read from HCP (not from input)."
  value       = local.hvn_cidr
}

output "vpc_cidr" {
  description = "Primary IPv4 CIDR of the VPC, read from AWS (empty when vpc_id is unset)."
  value       = local.vpc_cidr
}

# HVN peering outputs
output "hvn_peering_enabled" {
  description = "Whether Terraform manages an HVN <-> VPC peering (creates one, or adopts an existing one). false for a public cluster, or a private cluster relying on connectivity outside this config."
  value       = local.manage_peering
}

output "hvn_peering_adopted" {
  description = "Whether Terraform adopted a pre-existing peering (established outside this config) rather than creating one. null when no peering is managed."
  value       = local.manage_peering ? local.peering_adopted : null
}

output "hvn_peering_created" {
  description = "Whether Terraform created the peering (false means an existing one was adopted)."
  value       = local.manage_peering ? module.vault_hvn_peering[0].peering_created : null
}

output "hcp_peering_id" {
  description = "Slug ID of the HCP network peering resource."
  value       = local.manage_peering ? module.vault_hvn_peering[0].hcp_peering_id : null
}

output "aws_peering_connection_id" {
  description = "AWS VPC peering connection ID (pcx-...) for the HVN peering."
  value       = local.manage_peering ? module.vault_hvn_peering[0].aws_peering_connection_id : null
}

output "hvn_peering_state" {
  description = "Current state of the HCP network peering."
  value       = local.manage_peering ? module.vault_hvn_peering[0].peering_state : null
}

output "hvn_peering_hvn_route_ids" {
  description = "Slug IDs of the HVN routes that point back at the VPC CIDR(s)."
  value       = local.manage_peering ? module.vault_hvn_peering[0].hvn_route_ids : null
}

output "hvn_peering_aws_route_table_ids" {
  description = "AWS route table IDs that received a route to the HVN CIDR."
  value       = local.manage_peering ? module.vault_hvn_peering[0].aws_route_table_ids : null
}

output "hvn_peering_hvn_routes_adopted" {
  description = "VPC CIDRs whose HVN route already existed and was adopted rather than created."
  value       = local.manage_peering ? module.vault_hvn_peering[0].hvn_routes_adopted : null
}

output "hvn_peering_aws_routes_adopted" {
  description = "Route table IDs whose route to the HVN CIDR already existed and was adopted rather than created."
  value       = local.manage_peering ? module.vault_hvn_peering[0].aws_routes_adopted : null
}

# VPN outputs
output "vpn_enabled" {
  description = "Whether AWS Client VPN module was enabled."
  value       = local.enable_vpn
}

output "vpn_endpoint_id" {
  description = "ID of the created AWS Client VPN Endpoint."
  value       = local.enable_vpn ? module.vault_aws_client_vpn[0].vpn_endpoint_id : null
}

output "vpn_endpoint_dns_name" {
  description = "DNS name of the AWS Client VPN Endpoint."
  value       = local.enable_vpn ? module.vault_aws_client_vpn[0].vpn_endpoint_dns_name : null
}

output "ovpn_file_path" {
  description = "Path to the generated ready-to-use .ovpn client configuration file."
  value       = local.enable_vpn ? module.vault_aws_client_vpn[0].ovpn_file_path : null
}

output "ovpn_file_content" {
  description = "Raw text content of the generated .ovpn client configuration file."
  value       = local.enable_vpn ? module.vault_aws_client_vpn[0].ovpn_file_content : null
  sensitive   = true
}

output "usage_instructions" {
  description = "Instructions on how to use the generated .ovpn file to connect and access Vault."
  value       = local.enable_vpn ? module.vault_aws_client_vpn[0].usage_instructions : null
}
