variable "name" {
  type        = string
  description = "Name of the VNet."
}

variable "location" {
  type        = string
  description = "Azure region of the VNet."
}

variable "resource_group_name" {
  type        = string
  description = "Existing resource group that holds the VNet, its subnet and NSG."
}

variable "address_space" {
  type        = list(string)
  description = "IPv4 CIDR blocks of the VNet."
}

variable "workload_subnet_name" {
  type        = string
  description = "Name of the private subnet for workloads."
}

variable "workload_subnet_cidr" {
  type        = string
  description = "IPv4 CIDR of the workload subnet. Must sit inside address_space."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource that supports them."
  default     = {}
}
