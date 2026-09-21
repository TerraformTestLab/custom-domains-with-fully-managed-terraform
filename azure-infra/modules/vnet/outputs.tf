output "id" {
  description = "Resource ID of the VNet."
  value       = azurerm_virtual_network.this.id
}

output "name" {
  description = "Name of the VNet."
  value       = azurerm_virtual_network.this.name
}

output "address_space" {
  description = "CIDR blocks of the VNet."
  value       = azurerm_virtual_network.this.address_space
}

output "workload_subnet_id" {
  description = "Resource ID of the workload subnet."
  value       = azurerm_subnet.workload.id
}
