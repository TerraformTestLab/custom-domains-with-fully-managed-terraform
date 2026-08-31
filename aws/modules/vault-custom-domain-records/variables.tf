variable "route53_hosted_zone_name" {
  description = "Public Route53 hosted zone name."
  type        = string
}

variable "vault_record_name" {
  description = "Record prefix for the Vault CNAME record."
  type        = string
}

variable "vault_target_hostname" {
  description = "Target hostname for the Vault CNAME records."
  type        = string
}
