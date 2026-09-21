output "subscription_id" {
  description = "Subscription ID that holds the resources (an HCP peering input)."
  value       = data.azurerm_client_config.current.subscription_id
}

output "tenant_id" {
  description = "Tenant ID of the subscription (an HCP peering input)."
  value       = data.azurerm_client_config.current.tenant_id
}

output "location" {
  description = "Region of the resource groups and the VNet (an HCP peering input)."
  value       = var.location
}

output "resource_group_names" {
  description = "Names of the network, vault_access and dns resource groups."
  value       = module.resource_groups.names
}

output "virtual_network_name" {
  description = "Name of the VNet (an HCP peering input)."
  value       = module.vnet.name
}

output "virtual_network_id" {
  description = "Resource ID of the VNet (an HCP peering input)."
  value       = module.vnet.id
}

output "virtual_network_address_space" {
  description = "CIDR blocks of the VNet, which the HVN needs a route to."
  value       = module.vnet.address_space
}

output "workload_subnet_id" {
  description = "Resource ID of the workload subnet."
  value       = module.vnet.workload_subnet_id
}

output "dns_zones" {
  description = "Azure public DNS zones, keyed like the dns_zones input, with each zone's ID, name and Azure name servers."
  value       = module.dns_zones.zones
}
