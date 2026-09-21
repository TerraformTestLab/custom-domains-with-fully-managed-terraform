variable "subscription_id" {
  type        = string
  description = "ID of the Azure subscription everything is created in."

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$", var.subscription_id))
    error_message = "subscription_id must be a UUID."
  }
}

variable "location" {
  type        = string
  description = "Azure region for the resource groups and the VNet, e.g. \"westus2\". Must match the region of the HCP HVN the VNet will be peered with."

  validation {
    condition     = can(regex("^[a-z0-9]+$", var.location))
    error_message = "location must be a lowercase Azure region name without spaces, e.g. \"westus2\"."
  }
}

variable "aws_region" {
  type        = string
  description = "AWS region the aws provider is configured with. Route 53 is global, so any valid region works."
  default     = "us-west-2"
}

variable "resource_group_names" {
  type = object({
    network      = optional(string)
    vault_access = optional(string)
    dns          = optional(string)
  })
  description = "Optional resource group names. Unset entries default to rg-network-<location>, rg-vault-access-<location> and rg-dns."
  default     = {}
}

variable "virtual_network_name" {
  type        = string
  description = "Name of the VNet."
  default     = "vcs-vnet"
}

variable "virtual_network_address_space" {
  type        = list(string)
  description = "IPv4 CIDR blocks of the VNet."
  default     = ["10.0.0.0/16"]

  validation {
    condition     = length(var.virtual_network_address_space) > 0 && alltrue([for cidr in var.virtual_network_address_space : can(cidrhost(cidr, 0))])
    error_message = "virtual_network_address_space must be a non-empty list of valid IPv4 CIDRs."
  }
}

variable "workload_subnet_name" {
  type        = string
  description = "Name of the private subnet for workloads such as a jump box."
  default     = "vcs-workload-subnet"
}

variable "workload_subnet_cidr" {
  type        = string
  description = "IPv4 CIDR of the workload subnet. Must sit inside virtual_network_address_space."
  default     = "10.0.1.0/24"

  validation {
    condition     = can(cidrhost(var.workload_subnet_cidr, 0))
    error_message = "workload_subnet_cidr must be a valid IPv4 CIDR."
  }

  # Containment: the subnet is no larger than a VNet block, and masking the
  # subnet to that block's prefix lands on the block's network address. Skipped
  # while either input is malformed, since the other checks report that.
  validation {
    condition = !can(cidrhost(var.workload_subnet_cidr, 0)) || !alltrue([for cidr in var.virtual_network_address_space : can(cidrhost(cidr, 0))]) ? true : anytrue([
      for space in var.virtual_network_address_space :
      tonumber(split("/", space)[1]) <= tonumber(split("/", var.workload_subnet_cidr)[1])
      && cidrhost(format("%s/%d", cidrhost(var.workload_subnet_cidr, 0), tonumber(split("/", space)[1])), 0) == cidrhost(space, 0)
    ])
    error_message = "workload_subnet_cidr must sit inside virtual_network_address_space."
  }
}

variable "dns_zones" {
  type = map(object({
    parent_zone_name = string
    child_label      = string
  }))
  description = "Azure public DNS zones to create, keyed by any unique name. Each becomes <child_label>.<parent_zone_name> and is delegated from the existing public Route 53 zone parent_zone_name."

  validation {
    condition     = alltrue([for zone in values(var.dns_zones) : can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", zone.child_label))])
    error_message = "Each dns_zones child_label must be a single lowercase DNS label, e.g. \"az\"."
  }

  validation {
    condition     = alltrue([for zone in values(var.dns_zones) : can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$", zone.parent_zone_name))])
    error_message = "Each dns_zones parent_zone_name must be a bare lowercase domain, e.g. \"example.com\" - no scheme, no trailing dot."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource that supports them."
  default     = {}
}
