variable "vpc_id" {
  description = "The ID of the AWS VPC to connect the Client VPN to."
  type        = string

  validation {
    condition     = var.vpc_id != ""
    error_message = "vault-aws-client-vpn: vpc_id is required - the Client VPN attaches to a VPC."
  }
}

variable "subnet_id" {
  description = "The ID of a private subnet inside the VPC to associate with the Client VPN."
  type        = string

  validation {
    condition     = var.subnet_id != ""
    error_message = "vault-aws-client-vpn: subnet_id is required - the Client VPN endpoint associates with a subnet."
  }
}

variable "vpc_cidr" {
  description = "The IPv4 CIDR block of your AWS VPC (e.g. 10.0.0.0/16)."
  type        = string
}

variable "hvn_cidr" {
  description = "The IPv4 CIDR block of your HCP HVN (e.g. 172.25.16.0/20)."
  type        = string
}

variable "client_vpn_cidr" {
  description = "Non-overlapping IPv4 CIDR block for VPN clients (must be /22 or larger, e.g. 10.200.0.0/22)."
  type        = string
  default     = "10.200.0.0/22"

  validation {
    condition     = var.client_vpn_cidr != ""
    error_message = "vault-aws-client-vpn: client_vpn_cidr is required - the Client VPN needs an address pool for its clients."
  }
  validation {
    condition     = can(cidrhost(var.client_vpn_cidr, 0)) && tonumber(split("/", var.client_vpn_cidr)[1]) <= 22
    error_message = "vault-aws-client-vpn: client_vpn_cidr must be a valid IPv4 CIDR with a prefix of /22 or larger (<= 22)."
  }
}

variable "vault_fqdn" {
  description = "The FQDN of the Vault custom domain."
  type        = string
  default     = ""
}

variable "ovpn_output_path" {
  description = "File path to save the generated ready-to-use .ovpn client configuration file."
  type        = string
  default     = "vault-client-vpn.ovpn"
}
