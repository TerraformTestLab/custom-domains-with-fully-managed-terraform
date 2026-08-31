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

# Cross-cutting checks that need the real VPC / HVN CIDRs resolved. Runs only
# when this module is instantiated (never for a public cluster).
resource "terraform_data" "validations" {
  lifecycle {
    precondition {
      condition     = !local.vpc_hvn_overlap
      error_message = "vault-hvn-peering: the VPC CIDR(s) [${join(", ", local.vpc_cidr_blocks)}] overlap the HVN CIDR (${local._hvn_cidr}) - HVN peering routing cannot work. Re-CIDR one side."
    }
  }
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

  hvn_link         = data.hcp_hvn.this.self_link
  hvn_route_id     = "${var.hvn_route_id}-${replace(each.value, "/[./]/", "-")}"
  destination_cidr = each.value
  target_link      = local.peering_self_link

  depends_on = [aws_vpc_peering_connection_accepter.this]
}

# 4. AWS side: route the HVN CIDR through the peering from each relevant route table.
resource "aws_route" "hvn" {
  for_each = toset(var.manage_routes ? local.route_table_ids : [])

  route_table_id            = each.value
  destination_cidr_block    = data.hcp_hvn.this.cidr_block
  vpc_peering_connection_id = local.aws_peering_connection_id

  depends_on = [aws_vpc_peering_connection_accepter.this]
}
