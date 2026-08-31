variable "hvn_id" {
  description = "ID of the existing HCP HashiCorp Virtual Network (HVN) to peer with. Found in HCP Portal -> HVN overview."
  type        = string
}

variable "vpc_id" {
  description = "ID of the AWS VPC to peer with the HVN."
  type        = string

  validation {
    condition     = var.vpc_id != ""
    error_message = "vault-hvn-peering: vpc_id is required - HVN peering needs a VPC to peer with."
  }
}

variable "peer_vpc_region" {
  description = "AWS region the peer VPC lives in (e.g. us-west-2)."
  type        = string
}

variable "subnet_id" {
  description = "ID of the private subnet whose route table receives the route to the HVN CIDR. Used only when route_table_ids is empty."
  type        = string

  validation {
    condition     = var.subnet_id != ""
    error_message = "vault-hvn-peering: subnet_id is required - it identifies the route table that carries the HVN route when route_table_ids is not given."
  }
}

variable "route_table_ids" {
  description = "Explicit list of AWS route table IDs that should carry a route to the HVN CIDR. When empty, the route table associated with subnet_id is used."
  type        = list(string)
  default     = []
}

variable "peering_id" {
  description = "Slug identifier for the HCP network peering resource, used when create_peering is true."
  type        = string
  default     = "vault-vpc-peering"
}

variable "hvn_route_id" {
  description = "Slug identifier prefix for the HVN route(s) that point back at the peered VPC CIDR(s)."
  type        = string
  default     = "vpc-peering-route"
}

variable "create_peering" {
  description = "true -> create + accept the HVN <-> VPC peering. false -> adopt the peering named by existing_peering_id (which is then required)."
  type        = bool
  default     = true
}

variable "existing_peering_id" {
  description = "Slug ID of an existing HCP network peering to adopt. When set, the HVN <-> VPC peering connection already exists and was established outside this config - this module only looks it up (data source) and routes through it, never creating or changing the connection. Must be empty when create_peering is true."
  type        = string
  default     = ""

  validation {
    condition     = !(var.create_peering && var.existing_peering_id != "")
    error_message = "vault-hvn-peering: create_peering = true requires existing_peering_id to be empty - Terraform is creating the peering, not adopting an existing one."
  }
}

variable "manage_routes" {
  description = "Whether this module manages BOTH route directions for the peering (the hcp_hvn_route entries for the VPC CIDR(s) AND the aws_route entries for the HVN CIDR). All-or-nothing: routing is never split between Terraform and manual management."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to AWS resources created by this module."
  type        = map(string)
  default     = {}
}
