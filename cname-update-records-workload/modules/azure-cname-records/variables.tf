variable "hosted_zone_name" {
  type        = string
  description = "Existing public Azure DNS zone that receives the records. Looked up by name in the subscription."
}

variable "vault_target_hostname" {
  type        = string
  description = "Hostname the Vault custom domain points at."
}
