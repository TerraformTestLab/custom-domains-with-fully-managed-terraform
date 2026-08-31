variable "enabled" {
  description = "Master toggle for Vault audit-log streaming. When false, no audit_log_config is emitted regardless of the destination blocks below."
  type        = bool
  default     = false
}

variable "cloudwatch" {
  description = "Stream audit logs to AWS CloudWatch Logs. Leave null to not use CloudWatch."
  type = object({
    region            = string
    group_name        = string
    stream_name       = optional(string)
    access_key_id     = optional(string)
    secret_access_key = optional(string)
  })
  default   = null
  sensitive = true
}

variable "datadog" {
  description = "Stream audit logs to Datadog. Leave null to not use Datadog."
  type = object({
    api_key = string
    region  = string
  })
  default   = null
  sensitive = true
}

variable "elasticsearch" {
  description = "Stream audit logs to Elasticsearch. Leave null to not use Elasticsearch."
  type = object({
    endpoint = string
    dataset  = optional(string)
    user     = string
    password = string
  })
  default   = null
  sensitive = true
}

variable "grafana" {
  description = "Stream audit logs to Grafana Loki. Leave null to not use Grafana."
  type = object({
    endpoint = string
    user     = string
    password = string
  })
  default   = null
  sensitive = true
}

variable "splunk" {
  description = "Stream audit logs to Splunk via HTTP Event Collector. Leave null to not use Splunk."
  type = object({
    hec_endpoint = string
    token        = string
  })
  default   = null
  sensitive = true
}

variable "newrelic" {
  description = "Stream audit logs to New Relic. Leave null to not use New Relic."
  type = object({
    account_id  = string
    license_key = string
    region      = string
  })
  default   = null
  sensitive = true
}

variable "http" {
  description = "Stream audit logs to a generic HTTP endpoint. Leave null to not use a custom HTTP sink."
  type = object({
    uri            = string
    method         = optional(string)
    codec          = optional(string)
    compression    = optional(bool)
    headers        = optional(map(string))
    basic_user     = optional(string)
    basic_password = optional(string)
    bearer_token   = optional(string)
    payload_prefix = optional(string)
    payload_suffix = optional(string)
  })
  default   = null
  sensitive = true
}
