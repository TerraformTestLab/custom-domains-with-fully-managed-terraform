###############################################################################
# Provider / global
###############################################################################

variable "aws_region" {
  description = "AWS Region where resources are deployed."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-\\d$", var.aws_region))
    error_message = "aws_region must be set in terraform.tfvars and look like an AWS region, e.g. \"us-west-2\"."
  }
}

variable "hcp_project_id" {
  description = "HCP project ID that owns the HVN and Vault cluster."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$", var.hcp_project_id))
    error_message = "hcp_project_id must be set in terraform.tfvars and be a UUID."
  }
}

variable "hcp_organization_id" {
  description = "HCP organization ID that owns the HVN and Vault cluster. Required ONLY for a private cluster that manages its peering routes (manage_peering_routes = true): the plan reads the HVN's existing routes from the HCP API to adopt them instead of failing on a duplicate. Leave \"\" for a public cluster or when manage_peering_routes = false."
  type        = string
  default     = ""

  validation {
    condition     = var.hcp_organization_id == "" || can(regex("^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$", var.hcp_organization_id))
    error_message = "hcp_organization_id must be \"\" or a UUID."
  }
}

###############################################################################
# Custom domain (Route53)
###############################################################################

variable "route53_hosted_zone_name" {
  description = "Public Route53 hosted zone name (bare domain, no scheme, no trailing dot)."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\\.)+[a-zA-Z]{2,63}$", var.route53_hosted_zone_name))
    error_message = "route53_hosted_zone_name must be set in terraform.tfvars as a bare domain such as \"example.com\" - no scheme, no trailing dot."
  }
}

variable "vault_record_name" {
  description = "Left-most label of the Vault custom domain. Must be \"vault\" - the custom domain is always vault.<route53_hosted_zone_name>."
  type        = string
  default     = ""

  validation {
    condition     = var.vault_record_name == "vault"
    error_message = "vault_record_name must be set to \"vault\" in terraform.tfvars. The custom domain is always vault.<route53_hosted_zone_name> - an empty value or any other label fails."
  }
}

###############################################################################
# HCP Vault cluster (vault-cluster module)
###############################################################################

variable "cluster_id" {
  description = "ID of the HCP Vault cluster this config manages - created when create_cluster is true, adopted (read only) when false."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{1,34}[a-z0-9])?$", var.cluster_id)) && length(var.cluster_id) >= 3 && length(var.cluster_id) <= 36
    error_message = "cluster_id must be set in terraform.tfvars: 3-36 chars, lowercase alphanumeric and hyphens, no leading/trailing hyphen."
  }
}

variable "create_cluster" {
  description = "true -> Terraform creates the cluster (vault_tier is then required). false -> adopt an existing cluster with this cluster_id (vault_tier, min_vault_version and audit logging must then be left at defaults / off)."
  type        = bool
  default     = false
}

variable "public_link" {
  description = "REQUIRED, no default - set explicitly (true|false) for both create and adopt. true -> custom domain targets the public endpoint and NO Client VPN or HVN peering is created, whatever the networking vars say. false -> targets the private endpoint; enable_vpn and create_hvn_peering must then also be set. The root module errors out if this is left unset."
  type        = bool
  default     = null
}

variable "vault_tier" {
  description = "HCP Vault cluster tier. Required when create_cluster is true; must be left empty when adopting (create_cluster = false)."
  type        = string
  default     = ""

  validation {
    condition     = var.vault_tier == "" || contains(["dev", "starter_small", "standard_small", "standard_medium", "standard_large", "plus_small", "plus_medium", "plus_large"], lower(var.vault_tier))
    error_message = "vault_tier must be \"\" or one of: dev, starter_small, standard_small, standard_medium, standard_large, plus_small, plus_medium, plus_large."
  }
}

variable "min_vault_version" {
  description = "Minimum Vault version (e.g. \"v1.19.0\"). Null selects the latest. Only applied when create_cluster is true."
  type        = string
  default     = null

  validation {
    condition     = var.min_vault_version == null || can(regex("^v\\d+\\.\\d+\\.\\d+$", var.min_vault_version))
    error_message = "min_vault_version must look like \"v1.19.0\" or be null."
  }
}

###############################################################################
# Vault audit log streaming
#
#   audit_log_enabled = false  -> no audit logging; nothing else here matters.
#   audit_log_enabled = true   -> pick a destination:
#     cloudwatch_audit_log_enabled = true  -> Terraform creates + manages it.
#     cloudwatch_audit_log_enabled = false -> supply exactly audit_log_sink_count
#                                             audit_log_<vendor> object(s).
#
#   Enforced by preconditions in main.tf: master switch required, destination
#   resolvable, no CloudWatch/vendor clash, not while adopting a cluster.
###############################################################################

variable "audit_log_enabled" {
  description = "Master switch for Vault audit-log streaming. false -> no audit_log_config on the cluster."
  type        = bool
  default     = false
}

variable "audit_log_sink_count" {
  description = "How many external audit_log_<vendor> objects must be set when the external-sink path is active. HCP Vault accepts exactly one audit_log_config, so this is 1."
  type        = number
  default     = 1

  validation {
    condition     = var.audit_log_sink_count == 1
    error_message = "audit_log_sink_count: HCP Vault accepts exactly one audit_log_config sink - only 1 is supported."
  }
}

# --- Destination A: Terraform-managed CloudWatch (cloudwatch-audit-log module) ---
variable "cloudwatch_audit_log_enabled" {
  description = "When audit_log_enabled is true: have Terraform create + manage the CloudWatch destination (log group + dedicated IAM user/key) instead of pointing at an external sink."
  type        = bool
  default     = false
}

variable "cloudwatch_audit_log_group_name" {
  description = "Override the CloudWatch log group name. Empty derives \"/hcp/vault/<cluster_id>/audit\"."
  type        = string
  default     = ""

  validation {
    condition     = var.cloudwatch_audit_log_group_name == "" || can(regex("^[-A-Za-z0-9_./#]{1,512}$", var.cloudwatch_audit_log_group_name))
    error_message = "cloudwatch_audit_log_group_name has invalid characters or exceeds 512 chars."
  }
}

variable "cloudwatch_audit_log_retention_days" {
  description = "Retention for the CloudWatch audit log group in days. 0 = keep forever."
  type        = number
  default     = 30

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.cloudwatch_audit_log_retention_days)
    error_message = "cloudwatch_audit_log_retention_days must be a CloudWatch-allowed value: 0,1,3,5,7,14,30,60,90,120,150,180,365,400,545,731,1096,1827,2192,2557,2922,3288,3653."
  }
}

# --- Destination B: external sink (vault-audit-log module) ---
# Used when audit_log_enabled = true AND cloudwatch_audit_log_enabled = false.
# Set exactly one of the objects below.
variable "audit_log_cloudwatch" {
  description = "Point at a CloudWatch log group + IAM credentials you manage yourself. Use cloudwatch_audit_log_enabled instead to have Terraform create one."
  type = object({
    region            = string
    group_name        = string
    stream_name       = optional(string)
    access_key_id     = optional(string)
    secret_access_key = optional(string)
  })
  default   = null
  sensitive = true

  validation {
    condition     = var.audit_log_cloudwatch == null || can(regex("^[a-z]{2}-[a-z]+-\\d$", var.audit_log_cloudwatch.region))
    error_message = "audit_log_cloudwatch.region must look like an AWS region, e.g. \"us-west-2\"."
  }
  validation {
    condition     = var.audit_log_cloudwatch == null || ((var.audit_log_cloudwatch.access_key_id == null) == (var.audit_log_cloudwatch.secret_access_key == null))
    error_message = "audit_log_cloudwatch: set access_key_id and secret_access_key together, or neither."
  }
}

variable "audit_log_datadog" {
  description = "Datadog audit-log destination."
  type = object({
    api_key = string
    region  = string
  })
  default   = null
  sensitive = true

  validation {
    condition     = var.audit_log_datadog == null || contains(["us1", "us3", "us5", "eu1", "ap1", "us1-fed"], var.audit_log_datadog.region)
    error_message = "audit_log_datadog.region must be one of: us1, us3, us5, eu1, ap1, us1-fed."
  }
}

variable "audit_log_elasticsearch" {
  description = "Elasticsearch audit-log destination."
  type = object({
    endpoint = string
    dataset  = optional(string)
    user     = string
    password = string
  })
  default   = null
  sensitive = true

  validation {
    condition     = var.audit_log_elasticsearch == null || startswith(var.audit_log_elasticsearch.endpoint, "https://")
    error_message = "audit_log_elasticsearch.endpoint must be an https:// URL."
  }
}

variable "audit_log_grafana" {
  description = "Grafana Loki audit-log destination."
  type = object({
    endpoint = string
    user     = string
    password = string
  })
  default   = null
  sensitive = true

  validation {
    condition     = var.audit_log_grafana == null || startswith(var.audit_log_grafana.endpoint, "http")
    error_message = "audit_log_grafana.endpoint must be a URL."
  }
}

variable "audit_log_splunk" {
  description = "Splunk HTTP Event Collector audit-log destination."
  type = object({
    hec_endpoint = string
    token        = string
  })
  default   = null
  sensitive = true

  validation {
    condition     = var.audit_log_splunk == null || startswith(var.audit_log_splunk.hec_endpoint, "http")
    error_message = "audit_log_splunk.hec_endpoint must be a URL."
  }
}

variable "audit_log_newrelic" {
  description = "New Relic audit-log destination."
  type = object({
    account_id  = string
    license_key = string
    region      = string
  })
  default   = null
  sensitive = true

  validation {
    condition     = var.audit_log_newrelic == null || contains(["US", "EU"], upper(var.audit_log_newrelic.region))
    error_message = "audit_log_newrelic.region must be US or EU."
  }
}

variable "audit_log_http" {
  description = "Generic HTTP audit-log destination."
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

  validation {
    condition = var.audit_log_http == null || (
      startswith(var.audit_log_http.uri, "http")
      && (var.audit_log_http.method == null || contains(["POST", "PUT"], upper(var.audit_log_http.method)))
      && (var.audit_log_http.codec == null || contains(["json", "ndjson"], lower(var.audit_log_http.codec)))
    )
    error_message = "audit_log_http: uri must be a URL; method (if set) POST or PUT; codec (if set) json or ndjson."
  }
}

###############################################################################
# AWS networking (shared by the VPN and HVN peering modules)
###############################################################################

variable "vpc_id" {
  description = "ID of the AWS VPC connected to the HCP HVN. Required when the VPN or HVN peering is active. Ignored - and its format left unchecked - when public_link = true, so a leftover placeholder does not block a public-endpoint plan."
  type        = string
  default     = ""

  validation {
    # public_link = true (or not yet set) never touches the VPC, so the format
    # is only enforced for a private cluster.
    condition     = var.public_link != false || var.vpc_id == "" || can(regex("^vpc-([0-9a-f]{8}|[0-9a-f]{17})$", var.vpc_id))
    error_message = "vpc_id must be \"\" or a valid VPC ID (vpc- followed by 8 or 17 hex chars)."
  }
}

variable "subnet_id" {
  description = "ID of a private subnet inside vpc_id for the Client VPN association / HVN route table. Required when the VPN or HVN peering is active. Ignored - and its format left unchecked - when public_link = true."
  type        = string
  default     = ""

  validation {
    condition     = var.public_link != false || var.subnet_id == "" || can(regex("^subnet-([0-9a-f]{8}|[0-9a-f]{17})$", var.subnet_id))
    error_message = "subnet_id must be \"\" or a valid subnet ID (subnet- followed by 8 or 17 hex chars)."
  }
}

variable "client_vpn_cidr" {
  description = "Non-overlapping IPv4 CIDR block for VPN clients (/22 or larger). Required when the Client VPN is active. Overlap with the VPC or HVN CIDR fails the plan. Ignored - and its format left unchecked - when public_link = true."
  type        = string
  default     = ""

  validation {
    condition     = var.public_link != false || var.client_vpn_cidr == "" || (can(cidrhost(var.client_vpn_cidr, 0)) && tonumber(split("/", var.client_vpn_cidr)[1]) <= 22)
    error_message = "client_vpn_cidr must be \"\" or a valid IPv4 CIDR with a prefix of /22 or larger (<= 22)."
  }
}

variable "enable_vpn" {
  description = "REQUIRED when public_link = false; ignored when public_link = true. true -> create the AWS Client VPN. false -> skip it (a warning at the end of plan/apply notes that a network path to Vault must exist outside this config, e.g. Transit Gateway or Direct Connect). No default - the root module errors out if unset on a private cluster."
  type        = bool
  default     = null
}

###############################################################################
# HCP HVN <-> VPC peering (vault-hvn-peering module)
###############################################################################

variable "hvn_id" {
  description = "ID of the existing HCP HVN that hosts the Vault cluster and is peered with the AWS VPC. HCP Portal -> HVN overview."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{1,34}[a-z0-9])?$", var.hvn_id)) && length(var.hvn_id) >= 3 && length(var.hvn_id) <= 36
    error_message = "hvn_id must be set in terraform.tfvars as a valid HCP slug (3-36, lowercase alphanumeric/hyphen). Set it from HCP Portal -> HVN overview."
  }
}

variable "create_hvn_peering" {
  description = "REQUIRED when public_link = false; ignored when public_link = true. true -> Terraform creates + accepts a new HVN <-> VPC peering (existing_hvn_peering_id must be empty). false -> Terraform does NOT create a peering: it adopts the one named by existing_hvn_peering_id if that is set, or - if that is empty too - manages no peering at all and assumes connectivity exists outside this config. No default - the root module errors out if unset on a private cluster."
  type        = bool
  default     = null
}

variable "existing_hvn_peering_id" {
  description = "HCP-side network-peering slug (HCP Portal -> HVN -> Peerings, e.g. \"vault-vpc-peering\" - NOT the AWS pcx- id). When non-empty, the HVN <-> VPC peering connection ALREADY EXISTS: it was established between AWS and HCP outside this config and its lifecycle is owned elsewhere. This config never creates, modifies, or deletes it - it only looks it up (data source) and uses it for networking. Must be empty when create_hvn_peering = true. Whether Terraform writes the route entries on top of the adopted peering is controlled independently by manage_peering_routes."
  type        = string
  default     = ""

  validation {
    condition     = var.existing_hvn_peering_id == "" || can(regex("^[a-z0-9]([a-z0-9-]{1,34}[a-z0-9])?$", var.existing_hvn_peering_id))
    error_message = "existing_hvn_peering_id must be \"\" or a valid HCP peering slug (3-36, lowercase alphanumeric/hyphen) - the HCP-side ID, not the AWS pcx- connection id."
  }
}

variable "manage_peering_routes" {
  description = "REQUIRED when public_link = false AND a peering is created or adopted (create_hvn_peering = true or existing_hvn_peering_id set); ignored otherwise. true -> Terraform manages BOTH route directions (the HVN routes for the VPC CIDR(s) AND the AWS routes for the HVN CIDR). false -> Terraform manages neither (a warning notes both directions must already exist). All-or-nothing - routing is never half Terraform, half manual. Independent of create_hvn_peering. No default - the root module errors out if unset when a peering is in play."
  type        = bool
  default     = null
}

variable "hvn_route_table_ids" {
  description = "Explicit AWS route table IDs to carry the route to the HVN CIDR. Empty -> the route table associated with subnet_id."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for r in var.hvn_route_table_ids : can(regex("^rtb-([0-9a-f]{8}|[0-9a-f]{17})$", r))])
    error_message = "each hvn_route_table_ids entry must be a valid route table ID (rtb- followed by 8 or 17 hex chars)."
  }
}
