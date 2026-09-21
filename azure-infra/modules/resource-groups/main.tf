locals {
  # The DNS group carries no region in its name: DNS zones are global.
  names = {
    network      = coalesce(var.names.network, "rg-network-${var.location}")
    vault_access = coalesce(var.names.vault_access, "rg-vault-access-${var.location}")
    dns          = coalesce(var.names.dns, "rg-dns")
  }
}

resource "azurerm_resource_group" "this" {
  for_each = local.names

  name     = each.value
  location = var.location
  tags     = var.tags
}
