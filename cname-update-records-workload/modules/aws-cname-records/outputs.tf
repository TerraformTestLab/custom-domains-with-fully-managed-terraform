output "fqdns" {
  description = "FQDNs of the vault and _acme-challenge CNAME records."
  value = {
    vault     = aws_route53_record.vault.fqdn
    challenge = aws_route53_record.challenge.fqdn
  }
}
