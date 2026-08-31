variable "cluster_id" {
  description = "ID of the HCP Vault cluster this module manages - created when create_cluster is true, adopted (read) when false."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{1,34}[a-z0-9])?$", var.cluster_id)) && length(var.cluster_id) >= 3 && length(var.cluster_id) <= 36
    error_message = "cluster_id must be 3-36 chars, lowercase alphanumeric and hyphens, no leading/trailing hyphen."
  }
}

variable "create_cluster" {
  description = "true -> create the cluster. false -> adopt (read) an existing cluster with this cluster_id; creation-only inputs (tier, min_vault_version, audit_log_config) must be left at their defaults."
  type        = bool
  default     = true
}

variable "hvn_id" {
  description = "ID of the existing HCP HVN the cluster is deployed into."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{1,34}[a-z0-9])?$", var.hvn_id)) && length(var.hvn_id) >= 3 && length(var.hvn_id) <= 36
    error_message = "hvn_id must be a valid HCP slug (3-36, lowercase alphanumeric/hyphen)."
  }
}

variable "public_link" {
  description = "Whether the cluster exposes a public endpoint. When true, vault_target_hostname resolves to the public host; otherwise the private host."
  type        = bool
  default     = false
}

variable "tier" {
  description = "HCP Vault cluster tier. Required when create_cluster is true; must be empty when adopting."
  type        = string
  default     = ""

  validation {
    condition     = var.tier == "" || contains(["dev", "starter_small", "standard_small", "standard_medium", "standard_large", "plus_small", "plus_medium", "plus_large"], lower(var.tier))
    error_message = "tier must be \"\" or one of: dev, starter_small, standard_small, standard_medium, standard_large, plus_small, plus_medium, plus_large."
  }
}

variable "min_vault_version" {
  description = "Minimum Vault version for the cluster (e.g. v1.19.0). Null selects the latest. Only applied when create_cluster is true."
  type        = string
  default     = null

  validation {
    condition     = var.min_vault_version == null || can(regex("^v\\d+\\.\\d+\\.\\d+$", var.min_vault_version))
    error_message = "min_vault_version must look like \"v1.19.0\" or be null."
  }
}

variable "audit_log_enabled" {
  description = "The root audit_log_enabled master switch. Used only to produce a clear error when audit logging is requested on an adopted cluster (create_cluster = false)."
  type        = bool
  default     = false
}

variable "audit_log_config" {
  description = "audit_log_config block payload (single-element list) or []. Only applied when create_cluster is true."
  type        = list(any)
  default     = []
}
