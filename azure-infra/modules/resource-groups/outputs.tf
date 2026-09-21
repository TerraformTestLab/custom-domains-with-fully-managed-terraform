output "names" {
  description = "Resource group names, keyed by role: network, vault_access and dns."
  value       = { for role, group in azurerm_resource_group.this : role => group.name }
}
