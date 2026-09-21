# Looking the zone up by name doubles as the existence check: the plan fails
# when the zone is missing. With no resource group given, the provider returns
# the first zone in the subscription with this name.
data "azurerm_dns_zone" "this" {
  name = var.hosted_zone_name
}

locals {
  # The zone ID is /subscriptions/<id>/resourceGroups/<group>/providers/...
  resource_group_name = regex("(?i)/resourceGroups/([^/]+)/", data.azurerm_dns_zone.this.id)[0]
}

# Azure cannot overwrite a record it does not manage: one that already exists
# must be imported into state first (terraform import), or the apply fails.
resource "azurerm_dns_cname_record" "vault" {
  name                = "vault"
  zone_name           = data.azurerm_dns_zone.this.name
  resource_group_name = local.resource_group_name
  ttl                 = 300
  record              = var.vault_target_hostname
}

resource "azurerm_dns_cname_record" "challenge" {
  name                = "_acme-challenge.vault"
  zone_name           = data.azurerm_dns_zone.this.name
  resource_group_name = local.resource_group_name
  ttl                 = 300
  record              = "_acme-challenge.${var.vault_target_hostname}"
}
