variable "audit_log_enabled" {
  description = "The root audit_log_enabled master switch. This module creates resources only when it is true AND cloudwatch_audit_log_enabled is true."
  type        = bool
  default     = false
}

variable "cloudwatch_audit_log_enabled" {
  description = "Whether the caller asked Terraform to own the CloudWatch audit destination. Requires audit_log_enabled = true (enforced by a precondition on the config output)."
  type        = bool
  default     = false
}

variable "cluster_id" {
  description = "HCP Vault cluster ID - used to name the log group and IAM user."
  type        = string

  validation {
    condition     = length(var.cluster_id) > 0
    error_message = "cluster_id is required."
  }
}

variable "aws_region" {
  description = "AWS region the CloudWatch log group lives in (passed to HCP as cloudwatch_region)."
  type        = string
}

variable "log_group_name" {
  description = "Override the CloudWatch log group name. Empty derives \"/hcp/vault/<cluster_id>/audit\"."
  type        = string
  default     = ""

  validation {
    condition     = var.log_group_name == "" || can(regex("^[-A-Za-z0-9_./#]{1,512}$", var.log_group_name))
    error_message = "log_group_name has invalid characters or exceeds 512 chars."
  }
}

variable "retention_in_days" {
  description = "CloudWatch log group retention. 0 keeps logs forever."
  type        = number
  default     = 30

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.retention_in_days)
    error_message = "retention_in_days must be a CloudWatch-allowed value: 0,1,3,5,7,14,30,60,90,120,150,180,365,400,545,731,1096,1827,2192,2557,2922,3288,3653."
  }
}

variable "tags" {
  description = "Tags applied to the log group and IAM user."
  type        = map(string)
  default     = {}
}
