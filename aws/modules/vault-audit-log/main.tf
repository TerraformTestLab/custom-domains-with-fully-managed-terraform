locals {
  # Whether a destination is configured is not itself a secret (the credentials
  # inside it are) - drop the sensitivity so it can drive outputs.
  present = {
    cloudwatch    = nonsensitive(var.cloudwatch != null)
    datadog       = nonsensitive(var.datadog != null)
    elasticsearch = nonsensitive(var.elasticsearch != null)
    grafana       = nonsensitive(var.grafana != null)
    splunk        = nonsensitive(var.splunk != null)
    newrelic      = nonsensitive(var.newrelic != null)
    http          = nonsensitive(var.http != null)
  }

  selected    = [for name, is_set in local.present : name if is_set]
  destination = var.enabled && length(local.selected) == 1 ? local.selected[0] : ""

  # Full attribute map matching the hcp_vault_cluster audit_log_config block.
  # Every key is always present (null when unused) so the consumer's dynamic
  # block can reference attributes directly without lookup().
  config_map = {
    cloudwatch_access_key_id     = try(var.cloudwatch.access_key_id, null)
    cloudwatch_group_name        = try(var.cloudwatch.group_name, null)
    cloudwatch_region            = try(var.cloudwatch.region, null)
    cloudwatch_secret_access_key = try(var.cloudwatch.secret_access_key, null)
    cloudwatch_stream_name       = try(var.cloudwatch.stream_name, null)

    datadog_api_key = try(var.datadog.api_key, null)
    datadog_region  = try(var.datadog.region, null)

    elasticsearch_dataset  = try(var.elasticsearch.dataset, null)
    elasticsearch_endpoint = try(var.elasticsearch.endpoint, null)
    elasticsearch_password = try(var.elasticsearch.password, null)
    elasticsearch_user     = try(var.elasticsearch.user, null)

    grafana_endpoint = try(var.grafana.endpoint, null)
    grafana_password = try(var.grafana.password, null)
    grafana_user     = try(var.grafana.user, null)

    http_basic_password = try(var.http.basic_password, null)
    http_basic_user     = try(var.http.basic_user, null)
    http_bearer_token   = try(var.http.bearer_token, null)
    http_codec          = try(var.http.codec, null)
    http_compression    = try(var.http.compression, null)
    http_headers        = try(var.http.headers, null)
    http_method         = try(var.http.method, null)
    http_payload_prefix = try(var.http.payload_prefix, null)
    http_payload_suffix = try(var.http.payload_suffix, null)
    http_uri            = try(var.http.uri, null)

    newrelic_account_id  = try(var.newrelic.account_id, null)
    newrelic_license_key = try(var.newrelic.license_key, null)
    newrelic_region      = try(var.newrelic.region, null)

    splunk_hecendpoint = try(var.splunk.hec_endpoint, null)
    splunk_token       = try(var.splunk.token, null)
  }

  config = var.enabled ? [local.config_map] : []
}
