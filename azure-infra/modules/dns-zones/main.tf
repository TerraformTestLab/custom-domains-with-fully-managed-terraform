data "aws_route53_zone" "parent" {
  for_each = var.zones

  name         = each.value.parent_zone_name
  private_zone = false
}

resource "azurerm_dns_zone" "this" {
  for_each = var.zones

  name                = "${each.value.child_label}.${each.value.parent_zone_name}"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Delegates the child zone to Azure by pointing its NS record, in the parent
# Route 53 zone, at the name servers Azure assigned to the new zone.
resource "aws_route53_record" "delegation" {
  for_each = var.zones

  zone_id = data.aws_route53_zone.parent[each.key].zone_id
  name    = azurerm_dns_zone.this[each.key].name
  type    = "NS"
  ttl     = 300
  records = azurerm_dns_zone.this[each.key].name_servers
}
