module "aws_cname_records" {
  source = "./modules/aws-cname-records"
  count  = contains(var.hosted_zone_cloud_provider, "aws") ? 1 : 0

  hosted_zone_name      = var.aws_hosted_zone_name
  vault_target_hostname = var.vault_target_hostname
}

module "azure_cname_records" {
  source = "./modules/azure-cname-records"
  count  = contains(var.hosted_zone_cloud_provider, "azure") ? 1 : 0

  hosted_zone_name      = var.azure_hosted_zone_name
  vault_target_hostname = var.vault_target_hostname
}
