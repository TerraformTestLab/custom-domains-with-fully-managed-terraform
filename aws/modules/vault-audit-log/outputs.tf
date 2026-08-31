output "config" {
  description = "audit_log_config block payload for hcp_vault_cluster: a single-element list when enabled with one destination, otherwise []."
  value       = local.config
  sensitive   = true

  precondition {
    condition     = !var.enabled || length(local.selected) == 1
    error_message = "vault-audit-log: audit logging is on with cloudwatch_audit_log_enabled = false, so exactly one audit_log_<vendor> object must be set (cloudwatch/datadog/elasticsearch/grafana/splunk/newrelic/http). Configured: ${length(local.selected)} (${join(", ", local.selected)})."
  }
}

output "enabled" {
  description = "Whether external-sink audit-log streaming is active."
  value       = var.enabled && length(local.selected) == 1
}

output "destination" {
  description = "Name of the selected audit-log destination, or \"\" when disabled."
  value       = local.destination
}

output "sink_count" {
  description = "How many audit_log_<vendor> objects are set (independent of the enabled toggle)."
  value       = length(local.selected)
}
