locals {
  create = var.create_cluster
}

# Create a new HCP Vault cluster.
resource "hcp_vault_cluster" "this" {
  count = local.create ? 1 : 0

  cluster_id        = var.cluster_id
  hvn_id            = var.hvn_id
  tier              = var.tier
  public_endpoint   = var.public_link
  min_vault_version = var.min_vault_version

  lifecycle {
    precondition {
      condition     = var.tier != ""
      error_message = "vault-cluster: create_cluster = true requires tier to be set (e.g. \"dev\", \"standard_small\")."
    }
  }

  # Fed by the cloudwatch-audit-log module: a single-element list carrying the
  # four cloudwatch_* attributes, or [] when audit logging is off.
  dynamic "audit_log_config" {
    for_each = var.audit_log_config
    content {
      cloudwatch_access_key_id     = audit_log_config.value.cloudwatch_access_key_id
      cloudwatch_group_name        = audit_log_config.value.cloudwatch_group_name
      cloudwatch_region            = audit_log_config.value.cloudwatch_region
      cloudwatch_secret_access_key = audit_log_config.value.cloudwatch_secret_access_key
    }
  }
}

# Or adopt an existing one.
data "hcp_vault_cluster" "existing" {
  count = local.create ? 0 : 1

  cluster_id = var.cluster_id

  # Creation-only inputs must not be set while adopting - a data source can only
  # read, so any of these would silently do nothing.
  lifecycle {
    precondition {
      condition     = !var.audit_log_enabled && length(var.audit_log_config) == 0
      error_message = "vault-cluster: create_cluster = false but audit logging is requested (audit_log_enabled = true or audit_log_config set). Audit logging can only be configured on a cluster this module creates."
    }
    precondition {
      condition     = var.tier == "" && var.min_vault_version == null
      error_message = "vault-cluster: create_cluster = false but tier / min_vault_version are set. They don't apply to an adopted cluster - leave them empty / null."
    }
  }
}

locals {
  # Select attribute-by-attribute so both branches share one object type
  # (the resource and data schemas differ in their nested blocks).
  cluster = local.create ? {
    cluster_id                 = hcp_vault_cluster.this[0].cluster_id
    self_link                  = hcp_vault_cluster.this[0].self_link
    namespace                  = hcp_vault_cluster.this[0].namespace
    tier                       = hcp_vault_cluster.this[0].tier
    vault_version              = hcp_vault_cluster.this[0].vault_version
    vault_private_endpoint_url = hcp_vault_cluster.this[0].vault_private_endpoint_url
    vault_public_endpoint_url  = hcp_vault_cluster.this[0].vault_public_endpoint_url
    } : {
    cluster_id                 = data.hcp_vault_cluster.existing[0].cluster_id
    self_link                  = data.hcp_vault_cluster.existing[0].self_link
    namespace                  = data.hcp_vault_cluster.existing[0].namespace
    tier                       = data.hcp_vault_cluster.existing[0].tier
    vault_version              = data.hcp_vault_cluster.existing[0].vault_version
    vault_private_endpoint_url = data.hcp_vault_cluster.existing[0].vault_private_endpoint_url
    vault_public_endpoint_url  = data.hcp_vault_cluster.existing[0].vault_public_endpoint_url
  }

  private_url = local.cluster.vault_private_endpoint_url
  public_url  = local.cluster.vault_public_endpoint_url

  endpoint_url = var.public_link ? local.public_url : local.private_url

  # Bare hostname for CNAME records: strip scheme and port.
  vault_target_hostname = replace(replace(local.endpoint_url, "https://", ""), ":8200", "")
}
