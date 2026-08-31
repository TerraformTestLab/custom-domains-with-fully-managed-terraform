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
  description = "Slug IDs of the HVN routes managed by this module (empty when manage_routes is false)."
  value       = [for r in hcp_hvn_route.vpc : r.hvn_route_id]
}

output "aws_route_table_ids" {
  description = "AWS route table IDs that received a route to the HVN CIDR (empty when manage_routes is false)."
  value       = [for r in aws_route.hvn : r.route_table_id]
}

output "routes_managed" {
  description = "Whether Terraform manages both route directions for this peering."
  value       = var.manage_routes
}
