output "peering_created" {
  description = "Whether this module created the peering (false means an existing one was adopted)."
  value       = var.create_peering
}

output "hcp_peering_id" {
  description = "Slug ID of the HCP network peering (created or adopted)."
  value       = local.hcp_peering_id
}

output "aws_peering_connection_id" {
  description = "AWS VPC peering connection ID (pcx-...) for the HVN peering."
  value       = local.aws_peering_connection_id
}

output "peering_state" {
  description = "Current state of the HCP network peering."
  value       = local.peering_state
}

output "hvn_cidr" {
  description = "IPv4 CIDR block of the peered HVN."
  value       = data.hcp_hvn.this.cidr_block
}

output "vpc_cidr_blocks" {
  description = "IPv4 CIDR blocks of the peered AWS VPC."
  value       = local.vpc_cidr_blocks
}

output "hvn_route_ids" {
  description = "Slug IDs of the HVN routes managed by this module - created and adopted (empty when manage_routes is false)."
  value       = [for r in hcp_hvn_route.vpc : r.hvn_route_id]
}

output "aws_route_table_ids" {
  description = "AWS route table IDs that carry a route to the HVN CIDR - created and adopted (empty when manage_routes is false)."
  value       = [for r in aws_route.hvn : r.route_table_id]
}

output "hvn_routes_adopted" {
  description = "Destination CIDRs whose HVN route already existed and was adopted rather than created."
  value       = var.manage_routes ? local.hvn_routes_adopted : []
}

output "aws_routes_adopted" {
  description = "Route table IDs whose route to the HVN CIDR already existed and was adopted rather than created."
  value       = var.manage_routes ? local.aws_routes_adopted : []
}

# Import blocks are only valid in the root module, so this module surfaces the
# adoption targets and the root wires them into `import` blocks. Populated only
# on the adopt path (create_peering = false) - a peering created in this run
# cannot already carry routes.
output "hvn_route_imports" {
  description = "Map of VPC CIDR => import ID for an HVN route that already exists and points at the adopted peering."
  value = (var.manage_routes && !var.create_peering) ? {
    for cidr, target in local.existing_hvn_route_target :
    cidr => "${var.hcp_project_id}:${var.hvn_id}:${local.existing_hvn_route_id[cidr]}"
    if target == local.hcp_peering_id
  } : {}
}

output "aws_route_imports" {
  description = "Map of route table ID => import ID for an AWS route to the HVN CIDR that already exists and points at the adopted peering connection."
  value = (var.manage_routes && !var.create_peering) ? {
    for rt, r in local._aws_route_to_hvn :
    rt => "${rt}_${local._hvn_cidr}"
    if r != null && r.vpc_peering_connection_id == local.aws_peering_connection_id
  } : {}
}

output "routes_managed" {
  description = "Whether Terraform manages both route directions for this peering."
  value       = var.manage_routes
}
