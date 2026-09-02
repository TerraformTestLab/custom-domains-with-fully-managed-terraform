data "aws_caller_identity" "current" {}

data "aws_vpc" "this" {
  id = var.vpc_id
}

# Route table that carries traffic for the associated subnet. Only consulted when
# this module manages routes and the caller did not pass an explicit
# route_table_ids list.
data "aws_route_table" "selected" {
  count     = var.manage_routes && length(var.route_table_ids) == 0 ? 1 : 0
  subnet_id = var.subnet_id
}

data "hcp_hvn" "this" {
  hvn_id = var.hvn_id
}

locals {
  # Every IPv4 CIDR attached to the peer VPC (primary + any secondary blocks).
  vpc_cidr_blocks = [for a in data.aws_vpc.this.cidr_block_associations : a.cidr_block]

  # Overlap test: mask both blocks to the coarser prefix and compare the network
  # addresses. A VPC CIDR that overlaps the HVN CIDR makes peering routes
  # unresolvable, so it is a hard error.
  _hvn_cidr   = data.hcp_hvn.this.cidr_block
  _hvn_prefix = tonumber(split("/", local._hvn_cidr)[1])
  vpc_hvn_overlap = anytrue([
    for c in local.vpc_cidr_blocks : (
      cidrhost(format("%s/%d", cidrhost(c, 0), min(tonumber(split("/", c)[1]), local._hvn_prefix)), 0)
      == cidrhost(format("%s/%d", cidrhost(local._hvn_cidr, 0), min(tonumber(split("/", c)[1]), local._hvn_prefix)), 0)
    )
  ])

  route_table_ids = length(var.route_table_ids) > 0 ? var.route_table_ids : (
    var.manage_routes ? [data.aws_route_table.selected[0].route_table_id] : []
  )

  # Resolve peering attributes from whichever of the managed resource or the
  # adopted data source is active.
  peering_self_link = var.create_peering ? (
    hcp_aws_network_peering.this[0].self_link
  ) : data.hcp_aws_network_peering.existing[0].self_link

  aws_peering_connection_id = var.create_peering ? (
    hcp_aws_network_peering.this[0].provider_peering_id
  ) : data.hcp_aws_network_peering.existing[0].provider_peering_id

  peering_state = var.create_peering ? (
    hcp_aws_network_peering.this[0].state
  ) : data.hcp_aws_network_peering.existing[0].state

  hcp_peering_id = var.create_peering ? (
    hcp_aws_network_peering.this[0].peering_id
  ) : var.existing_peering_id
}

###############################################################################
# Existing-route discovery
#
# manage_routes is all-or-nothing, but a peering established in the HCP portal -
# or a previous manual step - may already carry one or both route directions.
# Read the current state of both sides so an existing entry is ADOPTED (the
# import blocks below) instead of failing the apply on a duplicate create.
###############################################################################

locals {
  # hcp_api_address / hcp_api_token carry the HCP API host and bearer token for
  # the plan-time route read. The root sources both from the environment
  # (HCP_API_ADDRESS / HCP_API_TOKEN) and asserts they are set - this module
  # only consumes them.
  #
  # The HVN-route lookup can run only once its inputs are all present. Until then
  # the preconditions below report exactly what is missing.
  routes_lookup_ready = (
    var.manage_routes
    && var.hcp_organization_id != ""
    && var.hcp_project_id != ""
    && nonsensitive(var.hcp_api_token != "")
    && var.hcp_api_address != ""
  )
}

# Every route currently on the HVN, read straight from the HCP API.
data "http" "hvn_routes" {
  count = local.routes_lookup_ready ? 1 : 0
  url   = "https://${var.hcp_api_address}/network/2020-09-07/organizations/${var.hcp_organization_id}/projects/${var.hcp_project_id}/networks/${var.hvn_id}/routes"

  request_headers = {
    Authorization = "Bearer ${var.hcp_api_token}"
    Accept        = "application/json"
  }
}

# The route tables that will carry the AWS-side route, read to see which routes
# they already contain.
data "aws_route_table" "targets" {
  for_each       = var.manage_routes ? toset(local.route_table_ids) : toset([])
  route_table_id = each.value
}

locals {
  # --- HVN side: routes already present, keyed by destination CIDR ---
  _hvn_routes_raw = try(jsondecode(data.http.hvn_routes[0].response_body).routes, [])

  existing_hvn_route_target = {
    for r in local._hvn_routes_raw :
    r.destination => try(r.target.hvn_connection.id, "")
    if contains(local.vpc_cidr_blocks, try(r.destination, ""))
  }
  existing_hvn_route_id = {
    for r in local._hvn_routes_raw :
    r.destination => try(r.id, "")
    if contains(local.vpc_cidr_blocks, try(r.destination, ""))
  }

  hvn_routes_adopted = sort(keys(local.existing_hvn_route_target))
  hvn_routes_foreign = sort([
    for cidr, target in local.existing_hvn_route_target :
    cidr if target != local.hcp_peering_id
  ])

  # --- AWS side: existing route to the HVN CIDR per target route table ---
  _aws_route_to_hvn = {
    for rt, d in data.aws_route_table.targets :
    rt => try(one([for r in(d.routes == null ? [] : d.routes) : r if r.cidr_block == local._hvn_cidr]), null)
  }

  aws_routes_adopted = sort([for rt, r in local._aws_route_to_hvn : rt if r != null])
  aws_routes_foreign = sort([
    for rt, r in local._aws_route_to_hvn :
    rt if r != null && r.vpc_peering_connection_id != local.aws_peering_connection_id
  ])
}

# Cross-cutting checks that need the real VPC / HVN CIDRs and the HCP API read.
# Runs only when this module is instantiated (never for a public cluster).
resource "terraform_data" "validations" {
  lifecycle {
    precondition {
      condition     = !local.vpc_hvn_overlap
      error_message = "vault-hvn-peering: the VPC CIDR(s) [${join(", ", local.vpc_cidr_blocks)}] overlap the HVN CIDR (${local._hvn_cidr}) - HVN peering routing cannot work. Re-CIDR one side."
    }

    # manage_peering_routes = true => the plan reads the HVN's existing routes
    # from the HCP API. That needs an organization ID; the caller-supplied
    # hcp_api_address / hcp_api_token (both non-empty) are checked in the root.
    precondition {
      condition     = !var.manage_routes || (var.hcp_organization_id != null && var.hcp_organization_id != "")
      error_message = "vault-hvn-peering: hcp_organization_id must be set (non-empty) in terraform.tfvars when manage_peering_routes = true. It is the HCP organization whose existing HVN routes are read so they are adopted instead of duplicated. Find it in the HCP portal under Settings."
    }

    precondition {
      condition     = !local.routes_lookup_ready || data.http.hvn_routes[0].status_code == 200
      error_message = "vault-hvn-peering: reading HVN routes from HCP returned HTTP ${try(data.http.hvn_routes[0].status_code, 0)}. 401 or 403 - HCP_API_TOKEN is missing or expired, run 'hcp auth login' and re-export it. 404 - check HCP_API_ADDRESS, hcp_organization_id, hcp_project_id and hvn_id."
    }

    # A route that already exists for a VPC CIDR / to the HVN CIDR but points
    # somewhere other than this peering is not adopted - Terraform will not
    # silently rewrite a route it did not create.
    precondition {
      condition     = length(local.hvn_routes_foreign) == 0
      error_message = "vault-hvn-peering: the HVN already has a route for ${join(", ", local.hvn_routes_foreign)} pointing at a peering other than '${local.hcp_peering_id}'. Repoint or remove it before applying."
    }

    precondition {
      condition     = length(local.aws_routes_foreign) == 0
      error_message = "vault-hvn-peering: route table(s) ${join(", ", local.aws_routes_foreign)} already contain a route to the HVN CIDR ${local._hvn_cidr} via a different target than this peering. Repoint or remove it before applying."
    }
  }
}

# 1a. HCP side: request a new peering from the HVN into the AWS VPC.
resource "hcp_aws_network_peering" "this" {
  count = var.create_peering ? 1 : 0

  hvn_id          = var.hvn_id
  peering_id      = var.peering_id
  peer_account_id = data.aws_caller_identity.current.account_id
  peer_vpc_id     = var.vpc_id
  peer_vpc_region = var.peer_vpc_region
}

# 1b. Or adopt an existing peering (e.g. one created by hand in the HCP Portal).
data "hcp_aws_network_peering" "existing" {
  count = var.create_peering ? 0 : 1

  hvn_id     = var.hvn_id
  peering_id = var.existing_peering_id
}

# 2. AWS side: accept the peering connection. Only for peerings this module created.
resource "aws_vpc_peering_connection_accepter" "this" {
  count = var.create_peering ? 1 : 0

  vpc_peering_connection_id = hcp_aws_network_peering.this[0].provider_peering_id
  auto_accept               = true

  tags = merge(var.tags, {
    Name = "hcp-hvn-${var.hvn_id}"
  })
}

# 3. HVN side: route the VPC CIDR(s) back through the peering.
resource "hcp_hvn_route" "vpc" {
  for_each = toset(var.manage_routes ? local.vpc_cidr_blocks : [])

  hvn_link = data.hcp_hvn.this.self_link

  # Keep an adopted route's own ID (hvn_route_id is ForceNew); name a fresh one
  # with this module's scheme.
  hvn_route_id = (
    !var.create_peering && try(local.existing_hvn_route_target[each.value], "") == local.hcp_peering_id
    ? local.existing_hvn_route_id[each.value]
    : "${var.hvn_route_id}-${replace(each.value, "/[./]/", "-")}"
  )

  destination_cidr = each.value
  target_link      = local.peering_self_link

  depends_on = [aws_vpc_peering_connection_accepter.this, terraform_data.validations]
}

# 4. AWS side: route the HVN CIDR through the peering from each relevant route table.
resource "aws_route" "hvn" {
  for_each = toset(var.manage_routes ? local.route_table_ids : [])

  route_table_id            = each.value
  destination_cidr_block    = data.hcp_hvn.this.cidr_block
  vpc_peering_connection_id = local.aws_peering_connection_id

  depends_on = [aws_vpc_peering_connection_accepter.this, terraform_data.validations]
}
