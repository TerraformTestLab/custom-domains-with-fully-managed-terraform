variable "location" {
  type        = string
  description = "Azure region for the resource groups, e.g. \"westus2\"."
}

variable "names" {
  type = object({
    network      = optional(string)
    vault_access = optional(string)
    dns          = optional(string)
  })
  description = "Optional resource group names. Unset entries default to rg-network-<location>, rg-vault-access-<location> and rg-dns."
  default     = {}
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource group."
  default     = {}
}
