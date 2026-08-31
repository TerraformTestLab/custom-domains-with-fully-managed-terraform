locals {
  # Overlap test: mask both blocks to the coarser prefix and compare networks.
  # An empty peer CIDR (VPN active without a resolved VPC/HVN CIDR) is caught by
  # the presence preconditions below, so treat it as "no overlap" here.
  _overlap = {
    for p in [
      { key = "vpc", a = var.client_vpn_cidr, b = var.vpc_cidr },
      { key = "hvn", a = var.client_vpn_cidr, b = var.hvn_cidr },
      ] : p.key => (
      p.a == "" || p.b == "" ? false : (
        cidrhost(format("%s/%d", cidrhost(p.a, 0), min(tonumber(split("/", p.a)[1]), tonumber(split("/", p.b)[1]))), 0)
        == cidrhost(format("%s/%d", cidrhost(p.b, 0), min(tonumber(split("/", p.a)[1]), tonumber(split("/", p.b)[1]))), 0)
      )
    )
  }
}

# Cross-cutting checks. Runs only when this module is instantiated (never for a
# public cluster, and never when enable_vpn = false).
resource "terraform_data" "validations" {
  lifecycle {
    precondition {
      condition     = var.vpc_id != "" && var.subnet_id != ""
      error_message = "vault-aws-client-vpn: vpc_id and subnet_id are both required for the Client VPN."
    }
    precondition {
      condition     = !local._overlap["vpc"]
      error_message = "vault-aws-client-vpn: client_vpn_cidr (${var.client_vpn_cidr}) overlaps the VPC CIDR (${var.vpc_cidr})."
    }
    precondition {
      condition     = !local._overlap["hvn"]
      error_message = "vault-aws-client-vpn: client_vpn_cidr (${var.client_vpn_cidr}) overlaps the HVN CIDR (${var.hvn_cidr})."
    }
  }
}

# 1. Private Key for Certificate Authority (CA)
resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# 2. Self-signed CA Certificate
resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem

  subject {
    common_name  = "vpn-ca.hcp.vault"
    organization = "HashiCorp Demo"
  }

  validity_period_hours = 87600
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "crl_signing",
  ]
}

# 3. Private Key & Signed Cert for VPN Server
resource "tls_private_key" "server" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "server" {
  private_key_pem = tls_private_key.server.private_key_pem

  subject {
    common_name  = "server.vpn.hcp.vault"
    organization = "HashiCorp Demo"
  }
}

resource "tls_locally_signed_cert" "server" {
  cert_request_pem   = tls_cert_request.server.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# 4. Private Key & Signed Cert for VPN Client
resource "tls_private_key" "client" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "client" {
  private_key_pem = tls_private_key.client.private_key_pem

  subject {
    common_name  = "client.vpn.hcp.vault"
    organization = "HashiCorp Demo"
  }
}

resource "tls_locally_signed_cert" "client" {
  cert_request_pem   = tls_cert_request.client.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}

# 5. Import Certificates into ACM
resource "aws_acm_certificate" "server" {
  private_key       = tls_private_key.server.private_key_pem
  certificate_body  = tls_locally_signed_cert.server.cert_pem
  certificate_chain = tls_self_signed_cert.ca.cert_pem
}

resource "aws_acm_certificate" "client" {
  private_key       = tls_private_key.client.private_key_pem
  certificate_body  = tls_locally_signed_cert.client.cert_pem
  certificate_chain = tls_self_signed_cert.ca.cert_pem
}

# 6. AWS Client VPN Endpoint
resource "aws_ec2_client_vpn_endpoint" "this" {
  description            = "AWS Client VPN for HCP Vault Private Cluster Access"
  client_cidr_block      = var.client_vpn_cidr
  server_certificate_arn = aws_acm_certificate.server.arn
  split_tunnel           = true
  transport_protocol     = "udp"

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = aws_acm_certificate.client.arn
  }

  connection_log_options {
    enabled = false
  }

  dns_servers = [
    cidrhost(var.vpc_cidr, 2)
  ]

  tags = {
    Name = "hcp-vault-client-vpn"
  }
}

# 7. Network Association
resource "aws_ec2_client_vpn_network_association" "this" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  subnet_id              = var.subnet_id
}

# 8. Authorization Rules
resource "aws_ec2_client_vpn_authorization_rule" "vpc" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  target_network_cidr    = var.vpc_cidr
  authorize_all_groups   = true
}

resource "aws_ec2_client_vpn_authorization_rule" "hvn" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  target_network_cidr    = var.hvn_cidr
  authorize_all_groups   = true
}

# 9. Route to HCP HVN
resource "aws_ec2_client_vpn_route" "hvn" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  destination_cidr_block = var.hvn_cidr
  target_vpc_subnet_id   = aws_ec2_client_vpn_network_association.this.subnet_id

  depends_on = [
    aws_ec2_client_vpn_network_association.this
  ]
}

# 10. Generate Client OVPN Configuration File
resource "local_file" "ovpn" {
  filename        = var.ovpn_output_path
  file_permission = "0600"

  content = <<EOT
client
dev tun
proto udp
remote client-auth.${aws_ec2_client_vpn_endpoint.this.dns_name} 443
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
verb 3
reneg-sec 0

<ca>
${tls_self_signed_cert.ca.cert_pem}
</ca>

<cert>
${tls_locally_signed_cert.client.cert_pem}
</cert>

<key>
${tls_private_key.client.private_key_pem}
</key>
EOT
}
