variable "resource_group_name" {
  type        = string
  description = "Existing resource group that holds the Azure DNS zones."
}

variable "zones" {
  type = map(object({
    parent_zone_name = string
    child_label      = string
  }))
  description = "Zones to create, keyed by any unique name. Each becomes <child_label>.<parent_zone_name>, delegated from the existing public Route 53 zone parent_zone_name."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every Azure DNS zone."
  default     = {}
}
