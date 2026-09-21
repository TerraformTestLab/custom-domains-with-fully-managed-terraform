output "fqdns" {
  description = "FQDNs of the vault and _acme-challenge CNAME records."
  value = {
    vault     = azurerm_dns_cname_record.vault.fqdn
    challenge = azurerm_dns_cname_record.challenge.fqdn
  }
}
