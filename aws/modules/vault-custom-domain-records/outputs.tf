output "vault_cname_fqdn" {
  description = "FQDN of the Vault CNAME record."
  value       = aws_route53_record.vault_cname.fqdn
}

output "vault_challenge_cname_fqdn" {
  description = "FQDN of the ACME challenge CNAME record."
  value       = aws_route53_record.vault_challenge_cname.fqdn
}
