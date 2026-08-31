output "vpn_endpoint_id" {
  description = "The ID of the created AWS Client VPN Endpoint."
  value       = aws_ec2_client_vpn_endpoint.this.id
}

output "vpn_endpoint_dns_name" {
  description = "The DNS name of the Client VPN Endpoint."
  value       = aws_ec2_client_vpn_endpoint.this.dns_name
}

output "ovpn_file_path" {
  description = "The file path of the generated ready-to-use .ovpn client configuration file."
  value       = local_file.ovpn.filename
}

output "ovpn_file_content" {
  description = "The full raw text content of the generated .ovpn client configuration file."
  value       = local_file.ovpn.content
  sensitive   = true
}

output "usage_instructions" {
  description = "Instructions on how to use the generated .ovpn file to connect and access Vault."
  value       = <<EOT

================================================================================
                      AWS CLIENT VPN SETUP COMPLETE
================================================================================

1. SAVE THE .OVPN FILE TO YOUR LOCAL MACHINE:
   Since Terraform is running in Remote Execution Mode, save the file locally by running:
   terraform output -raw ovpn_file_content > vault-client-vpn.ovpn

2. HOW TO CONNECT:
   - Import 'vault-client-vpn.ovpn' into Tunnelblick, OpenVPN Connect,
     or AWS VPN Client on your laptop.
   - Click 'Connect'.

3. ACCESS VAULT UI:
   Once connected to the VPN, open your browser and navigate to:
   https://${var.vault_fqdn != "" ? var.vault_fqdn : "vault-custom-domain"}:8200/ui/

================================================================================
EOT
}
