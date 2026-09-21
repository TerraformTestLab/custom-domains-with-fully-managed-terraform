data "azurerm_client_config" "current" {}

module "resource_groups" {
  source = "./modules/resource-groups"

  location = var.location
  names    = var.resource_group_names
  tags     = var.tags
}

module "vnet" {
  source = "./modules/vnet"

  name                 = var.virtual_network_name
  location             = var.location
  resource_group_name  = module.resource_groups.names["network"]
  address_space        = var.virtual_network_address_space
  workload_subnet_name = var.workload_subnet_name
  workload_subnet_cidr = var.workload_subnet_cidr
  tags                 = var.tags
}

module "dns_zones" {
  source = "./modules/dns-zones"

  resource_group_name = module.resource_groups.names["dns"]
  zones               = var.dns_zones
  tags                = var.tags
}
