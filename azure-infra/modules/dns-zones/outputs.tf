output "delegations" {
  description = "NS delegation records written to the parent Route 53 zones, keyed like the zones input."
  value = {
    for key, record in aws_route53_record.delegation : key => {
      zone_id = record.zone_id
      name    = record.name
      type    = record.type
    }
  }
}

output "zones" {
  description = "Azure public DNS zones, keyed like the zones input, with each zone's ID, name and Azure name servers."
  value = {
    for key, zone in azurerm_dns_zone.this : key => {
      id           = zone.id
      name         = zone.name
      name_servers = zone.name_servers
    }
  }
}
