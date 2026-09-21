output "aws_cname_fqdns" {
  description = "FQDNs of the Route 53 vault and _acme-challenge CNAME records. Null when \"aws\" is not selected."
  value       = one(module.aws_cname_records[*].fqdns)
}

output "azure_cname_fqdns" {
  description = "FQDNs of the Azure DNS vault and _acme-challenge CNAME records. Null when \"azure\" is not selected."
  value       = one(module.azure_cname_records[*].fqdns)
}
