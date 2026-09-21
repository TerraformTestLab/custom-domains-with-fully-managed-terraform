variable "hosted_zone_name" {
  type        = string
  description = "Existing public Route 53 hosted zone that receives the records."
}

variable "vault_target_hostname" {
  type        = string
  description = "Hostname the Vault custom domain points at."
}
