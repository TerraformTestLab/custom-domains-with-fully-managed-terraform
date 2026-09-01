###############################################################################
# Derived facts + enablement
#
# Networking is never automatic. public_link decides whether a Client VPN or an
# HVN peering CAN exist at all; enable_vpn and create_hvn_peering are separate,
# conscious opt-ins for a private cluster. All four booleans (public_link,
# enable_vpn, create_hvn_peering, manage_peering_routes) have no default -
# terraform_data.root_preflight errors out when a required one is unset.
###############################################################################
locals {
  # public_link is mandatory (root_preflight reports it); the ?: keeps every
  # downstream expression type-safe until that error surfaces.
  _public_link        = var.public_link != null ? var.public_link : false
  is_public_endpoint  = local._public_link
  is_private_endpoint = !local._public_link

  _enable_vpn_in     = var.enable_vpn != null ? var.enable_vpn : false
  _create_peering_in = var.create_hvn_peering != null ? var.create_hvn_peering : false

  # Client VPN: private cluster + explicit opt-in. Forced off for a public
  # cluster no matter what enable_vpn says.
  enable_vpn = local.is_private_endpoint && local._enable_vpn_in

  # HVN peering is "in play" when the caller asks to create one, or points at an
  # existing (externally-managed) one via existing_hvn_peering_id. Neither set =>
  # no peering module; connectivity is assumed to exist outside this config.
  peering_requested = local._create_peering_in || var.existing_hvn_peering_id != ""
  manage_peering    = local.is_private_endpoint && local.peering_requested
  peering_adopted   = local.manage_peering && !local._create_peering_in

  vault_target_hostname = module.vault_cluster.vault_target_hostname

  # Network facts read from the real VPC / HVN instead of trusted from input.
  hvn_cidr = data.hcp_hvn.check.cidr_block
  vpc_cidr = var.vpc_id != "" ? data.aws_vpc.check[0].cidr_block : ""

  # Audit logging
  audit_manage_cloudwatch = var.audit_log_enabled && var.cloudwatch_audit_log_enabled
  audit_use_external_sink = var.audit_log_enabled && !var.cloudwatch_audit_log_enabled
  audit_log_config        = local.audit_manage_cloudwatch ? module.cloudwatch_audit_log.config : module.vault_audit_log.config
}

###############################################################################
# Existence / consistency checks against the real cloud state (plan time)
###############################################################################
data "hcp_hvn" "check" {
  hvn_id = var.hvn_id

  lifecycle {
    postcondition {
      condition     = self.region == var.aws_region
      error_message = "HVN ${var.hvn_id} is in region ${self.region}, but aws_region is ${var.aws_region}. The HVN, VPC, subnet and cluster must all be in the same region."
    }
  }
}

data "aws_vpc" "check" {
  count = var.vpc_id != "" ? 1 : 0
  id    = var.vpc_id
}

data "aws_subnet" "check" {
  count = var.vpc_id != "" && var.subnet_id != "" ? 1 : 0
  id    = var.subnet_id

  lifecycle {
    postcondition {
      condition     = self.vpc_id == var.vpc_id
      error_message = "subnet_id ${var.subnet_id} belongs to VPC ${self.vpc_id}, not vpc_id ${var.vpc_id}."
    }
  }
}

###############################################################################
# Audit log modules
###############################################################################
module "cloudwatch_audit_log" {
  source = "./modules/cloudwatch-audit-log"

  audit_log_enabled            = var.audit_log_enabled
  cloudwatch_audit_log_enabled = var.cloudwatch_audit_log_enabled
  cluster_id                   = var.cluster_id
  aws_region                   = var.aws_region
  log_group_name               = var.cloudwatch_audit_log_group_name
  retention_in_days            = var.cloudwatch_audit_log_retention_days
}

module "vault_audit_log" {
  source = "./modules/vault-audit-log"

  enabled       = local.audit_use_external_sink
  cloudwatch    = var.audit_log_cloudwatch
  datadog       = var.audit_log_datadog
  elasticsearch = var.audit_log_elasticsearch
  grafana       = var.audit_log_grafana
  splunk        = var.audit_log_splunk
  newrelic      = var.audit_log_newrelic
  http          = var.audit_log_http
}

###############################################################################
# Root preflight - required-variable guards.
#
# Each networking boolean must be set consciously. The conditions are written so
# exactly one message fires: while public_link is null every later check is a
# no-op (public_link != false is true), so only the first precondition trips.
###############################################################################
resource "terraform_data" "root_preflight" {
  lifecycle {
    precondition {
      condition     = var.public_link != null
      error_message = "public_link must be set explicitly in terraform.tfvars (true or false). It has no default and is required whether you create or adopt the cluster."
    }
    precondition {
      condition     = var.public_link != false || var.enable_vpn != null
      error_message = "enable_vpn must be set explicitly (true or false) for a private cluster (public_link = false). true creates the Client VPN; false skips it and assumes external connectivity."
    }
    precondition {
      condition     = var.public_link != false || var.create_hvn_peering != null
      error_message = "create_hvn_peering must be set explicitly (true or false) for a private cluster (public_link = false)."
    }
    precondition {
      condition = (
        var.public_link != false
        || !(coalesce(var.create_hvn_peering, false) || var.existing_hvn_peering_id != "")
        || var.manage_peering_routes != null
      )
      error_message = "manage_peering_routes must be set explicitly (true or false) when a peering is created or adopted (create_hvn_peering = true, or existing_hvn_peering_id set)."
    }
  }
}

###############################################################################
# Audit preflight - the two cross-module rules that need both audit modules'
# state at once. The single-module audit rules live in their modules
# (cloudwatch_audit_log_enabled => audit_log_enabled in cloudwatch-audit-log;
# audit_log_enabled => create_cluster in vault-cluster).
###############################################################################
resource "terraform_data" "audit_preflight" {
  lifecycle {
    precondition {
      condition     = !var.audit_log_enabled || var.cloudwatch_audit_log_enabled || module.vault_audit_log.sink_count == var.audit_log_sink_count
      error_message = "audit_log_enabled = true needs a destination: set cloudwatch_audit_log_enabled = true, or provide exactly ${var.audit_log_sink_count} audit_log_<vendor> object(s). Found: ${module.vault_audit_log.sink_count}."
    }
    precondition {
      condition     = !(var.cloudwatch_audit_log_enabled && module.vault_audit_log.sink_count > 0)
      error_message = "cloudwatch_audit_log_enabled = true manages its own destination - remove the audit_log_<vendor> object(s) (${module.vault_audit_log.sink_count} set)."
    }
  }
}

###############################################################################
# Advisory checks - warn at the end of plan AND apply, never block.
# Every condition is null-safe (coalesce) so it survives the window before
# root_preflight reports an unset boolean.
###############################################################################
check "public_cluster_networking_ignored" {
  assert {
    condition = (
      !local.is_public_endpoint
      || (
        coalesce(var.enable_vpn, false) != true
        && coalesce(var.create_hvn_peering, false) != true
        && coalesce(var.manage_peering_routes, false) != true
        && var.existing_hvn_peering_id == ""
        && length(var.hvn_route_table_ids) == 0
      )
    )
    error_message = "public_link = true: no Client VPN or HVN peering is ever created, so enable_vpn / create_hvn_peering / manage_peering_routes / existing_hvn_peering_id / hvn_route_table_ids are ignored."
  }
}

check "private_cluster_vpn_skipped" {
  assert {
    condition     = !local.is_private_endpoint || coalesce(var.enable_vpn, true) != false
    error_message = "enable_vpn = false on a private cluster: no Client VPN is created. Ensure a network path to Vault exists outside this config (Transit Gateway, Direct Connect, an existing VPN, ...)."
  }
}

check "private_cluster_peering_skipped" {
  assert {
    condition     = !local.is_private_endpoint || local.peering_requested
    error_message = "public_link = false with create_hvn_peering = false and existing_hvn_peering_id empty: Terraform manages no HVN peering. manage_peering_routes and hvn_route_table_ids are ignored; connectivity is assumed to exist outside this config."
  }
}

check "peering_routes_unmanaged" {
  assert {
    condition     = !local.manage_peering || coalesce(var.manage_peering_routes, false) == true
    error_message = "a peering is being created or adopted but manage_peering_routes = false: Terraform writes no route entries. Make sure BOTH the HVN route to the VPC CIDR(s) and the AWS route to the HVN CIDR already exist."
  }
}

check "hvn_route_table_ids_unused" {
  assert {
    condition     = length(var.hvn_route_table_ids) == 0 || (local.manage_peering && coalesce(var.manage_peering_routes, false))
    error_message = "hvn_route_table_ids is set but Terraform is not managing peering routes - it has no effect."
  }
}

###############################################################################
# Vault cluster + downstream modules
###############################################################################
module "vault_cluster" {
  source = "./modules/vault-cluster"

  cluster_id        = var.cluster_id
  create_cluster    = var.create_cluster
  hvn_id            = var.hvn_id
  public_link       = local._public_link
  tier              = var.vault_tier
  min_vault_version = var.min_vault_version
  audit_log_enabled = var.audit_log_enabled
  audit_log_config  = local.audit_log_config
}

module "vault_custom_domain_records" {
  source = "./modules/vault-custom-domain-records"

  route53_hosted_zone_name = var.route53_hosted_zone_name
  vault_record_name        = var.vault_record_name
  vault_target_hostname    = module.vault_cluster.vault_target_hostname
}

module "vault_hvn_peering" {
  count  = local.manage_peering ? 1 : 0
  source = "./modules/vault-hvn-peering"

  hvn_id          = var.hvn_id
  vpc_id          = var.vpc_id
  peer_vpc_region = var.aws_region
  subnet_id       = var.subnet_id
  route_table_ids = var.hvn_route_table_ids

  create_peering      = local._create_peering_in
  existing_peering_id = var.existing_hvn_peering_id
  manage_routes       = coalesce(var.manage_peering_routes, false)

  hcp_organization_id = var.hcp_organization_id
  hcp_project_id      = var.hcp_project_id
  hcp_api_address     = var.hcp_api_address
}

# Adopt HVN / AWS routes that already exist for this peering (e.g. created with
# the peering in the HCP portal) instead of failing the apply on a duplicate.
# The maps are empty unless manage_peering_routes = true and the peering is
# adopted; the module computes them from a live HCP API read at plan time.
import {
  for_each = local.manage_peering ? module.vault_hvn_peering[0].hvn_route_imports : {}
  to       = module.vault_hvn_peering[0].hcp_hvn_route.vpc[each.key]
  id       = each.value
}

import {
  for_each = local.manage_peering ? module.vault_hvn_peering[0].aws_route_imports : {}
  to       = module.vault_hvn_peering[0].aws_route.hvn[each.key]
  id       = each.value
}

module "vault_aws_client_vpn" {
  count  = local.enable_vpn ? 1 : 0
  source = "./modules/vault-aws-client-vpn"

  vpc_id           = var.vpc_id
  subnet_id        = var.subnet_id
  vpc_cidr         = local.vpc_cidr
  hvn_cidr         = local.hvn_cidr
  client_vpn_cidr  = var.client_vpn_cidr
  vault_fqdn       = module.vault_custom_domain_records.vault_cname_fqdn
  ovpn_output_path = "${path.root}/vault-client-vpn.ovpn"

  depends_on = [module.vault_hvn_peering]
}
