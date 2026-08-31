output "config" {
  description = "audit_log_config payload for hcp_vault_cluster: single-element list when enabled, otherwise []."
  value       = local.config
  sensitive   = true

  precondition {
    condition     = !var.cloudwatch_audit_log_enabled || var.audit_log_enabled
    error_message = "cloudwatch_audit_log_enabled = true requires audit_log_enabled = true - the Terraform-managed CloudWatch audit destination does nothing while the master switch is off."
  }
}

output "enabled" {
  description = "Whether the CloudWatch audit-log destination is active."
  value       = local.create
}

output "log_group_name" {
  description = "Name of the CloudWatch log group receiving the audit stream."
  value       = one(aws_cloudwatch_log_group.this[*].name)
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group."
  value       = one(aws_cloudwatch_log_group.this[*].arn)
}

output "iam_user_name" {
  description = "Name of the dedicated IAM user HCP uses to write the audit stream."
  value       = one(aws_iam_user.this[*].name)
}
