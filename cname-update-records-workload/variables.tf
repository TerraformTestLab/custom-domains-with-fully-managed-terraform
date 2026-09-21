variable "hosted_zone_cloud_provider" {
  type        = list(string)
  description = "Clouds whose hosted zone gets its Vault CNAME records updated: \"aws\", \"azure\" or both. Only the listed clouds are touched."

  validation {
    condition     = length(var.hosted_zone_cloud_provider) > 0
    error_message = "hosted_zone_cloud_provider must list at least one cloud: \"aws\", \"azure\" or both."
  }

  validation {
    condition     = alltrue([for cloud in var.hosted_zone_cloud_provider : contains(["aws", "azure"], cloud)])
    error_message = "hosted_zone_cloud_provider entries must be \"aws\" or \"azure\"."
  }

  validation {
    condition     = length(distinct(var.hosted_zone_cloud_provider)) == length(var.hosted_zone_cloud_provider)
    error_message = "hosted_zone_cloud_provider must not repeat a cloud."
  }

  validation {
    condition     = !contains(var.hosted_zone_cloud_provider, "aws") || var.aws_hosted_zone_name != null
    error_message = "\"aws\" is selected, so aws_hosted_zone_name must be set."
  }

  validation {
    condition     = !contains(var.hosted_zone_cloud_provider, "azure") || var.azure_hosted_zone_name != null
    error_message = "\"azure\" is selected, so azure_hosted_zone_name must be set."
  }
}

variable "aws_hosted_zone_name" {
  type        = string
  description = "Existing PUBLIC Route 53 hosted zone that receives the records (bare domain, no scheme, no trailing dot). Required when \"aws\" is selected."
  default     = null

  validation {
    condition     = var.aws_hosted_zone_name == null || can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$", var.aws_hosted_zone_name))
    error_message = "aws_hosted_zone_name must be a bare lowercase domain such as \"example.com\" - no scheme, no trailing dot."
  }
}

variable "azure_hosted_zone_name" {
  type        = string
  description = "Existing PUBLIC Azure DNS zone that receives the records (bare domain, no scheme, no trailing dot). Looked up by name in the subscription. Required when \"azure\" is selected."
  default     = null

  validation {
    condition     = var.azure_hosted_zone_name == null || can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$", var.azure_hosted_zone_name))
    error_message = "azure_hosted_zone_name must be a bare lowercase domain such as \"az.example.com\" - no scheme, no trailing dot."
  }
}

variable "vault_target_hostname" {
  type        = string
  description = "Hostname the Vault custom domain points at: the cluster's private endpoint host, bare, no scheme and no trailing dot. vault.<zone> gets this value and _acme-challenge.vault.<zone> gets _acme-challenge.<this>."

  validation {
    condition     = can(regex("^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\\.)+[A-Za-z]{2,63}$", var.vault_target_hostname))
    error_message = "vault_target_hostname must be a bare hostname - no scheme, no trailing dot, not empty."
  }
}

variable "aws_region" {
  type        = string
  description = "AWS region the aws provider is configured with. Route 53 is global, so any valid region works."
  default     = "us-west-2"
}
