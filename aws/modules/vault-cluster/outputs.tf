output "cluster_created" {
  description = "Whether this module created the cluster (false means an existing one was adopted)."
  value       = local.create
}

output "cluster_id" {
  description = "ID of the HCP Vault cluster."
  value       = local.cluster.cluster_id
}

output "self_link" {
  description = "HCP self_link of the cluster."
  value       = local.cluster.self_link
}

output "namespace" {
  description = "Root namespace of the cluster."
  value       = local.cluster.namespace
}

output "tier" {
  description = "Tier of the cluster."
  value       = local.cluster.tier
}

output "vault_version" {
  description = "Running Vault version of the cluster."
  value       = local.cluster.vault_version
}

output "vault_private_endpoint_url" {
  description = "Private endpoint URL of the cluster."
  value       = local.private_url
}

output "vault_public_endpoint_url" {
  description = "Public endpoint URL of the cluster (empty when no public endpoint)."
  value       = local.public_url
}

output "vault_target_hostname" {
  description = "Bare hostname (no scheme/port) of the active endpoint - public when public_link is true, otherwise private. Feeds vault-custom-domain-records."
  value       = local.vault_target_hostname
}
