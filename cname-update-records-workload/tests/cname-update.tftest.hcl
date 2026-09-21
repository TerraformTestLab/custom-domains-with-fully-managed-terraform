# Provider selection and input validation for the CNAME update config.
#
#   terraform init -backend=false && terraform test
#
# Both providers are mocked, so no AWS or Azure credentials or network calls are
# needed. `-backend=false` skips the HCP Terraform `cloud` block in backend.tf.
# The zone lookups that fail on a missing zone are provider behaviour and are not
# exercised here.

mock_provider "aws" {
  mock_data "aws_route53_zone" {
    defaults = {
      zone_id = "Z0000000000000000000"
    }
  }
}

mock_provider "azurerm" {
  mock_data "azurerm_dns_zone" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-dns/providers/Microsoft.Network/dnsZones/az.sujay-samanta.sbx.hashidemos.io"
    }
  }
}

variables {
  hosted_zone_cloud_provider = ["aws", "azure"]
  aws_hosted_zone_name       = "sujay-samanta.sbx.hashidemos.io"
  azure_hosted_zone_name     = "az.sujay-samanta.sbx.hashidemos.io"
  vault_target_hostname      = "vault-private.example.hashicorp.cloud"
}

run "both_clouds_run_both_modules" {
  command = plan

  assert {
    condition     = length(module.aws_cname_records) == 1 && length(module.azure_cname_records) == 1
    error_message = "Expected both modules to run."
  }

  assert {
    condition     = toset(keys(module.aws_cname_records[0].fqdns)) == toset(["vault", "challenge"]) && toset(keys(module.azure_cname_records[0].fqdns)) == toset(["vault", "challenge"])
    error_message = "Expected a vault and a challenge record in each cloud."
  }
}

run "aws_only_runs_only_the_aws_module" {
  command = plan

  variables {
    hosted_zone_cloud_provider = ["aws"]
  }

  assert {
    condition     = length(module.aws_cname_records) == 1 && length(module.azure_cname_records) == 0
    error_message = "Expected only the aws module."
  }
}

run "azure_only_runs_only_the_azure_module" {
  command = plan

  variables {
    hosted_zone_cloud_provider = ["azure"]
  }

  assert {
    condition     = length(module.aws_cname_records) == 0 && length(module.azure_cname_records) == 1
    error_message = "Expected only the azure module."
  }
}

run "aws_only_needs_no_azure_zone" {
  command = plan

  variables {
    hosted_zone_cloud_provider = ["aws"]
    azure_hosted_zone_name     = null
  }

  assert {
    condition     = length(module.aws_cname_records) == 1
    error_message = "An aws-only run must not need an Azure zone."
  }
}

run "azure_only_needs_no_aws_zone" {
  command = plan

  variables {
    hosted_zone_cloud_provider = ["azure"]
    aws_hosted_zone_name       = null
  }

  assert {
    condition     = length(module.azure_cname_records) == 1
    error_message = "An azure-only run must not need an AWS zone."
  }
}

run "empty_provider_list_is_rejected" {
  command = plan

  variables {
    hosted_zone_cloud_provider = []
  }

  expect_failures = [var.hosted_zone_cloud_provider]
}

run "unsupported_provider_is_rejected" {
  command = plan

  variables {
    hosted_zone_cloud_provider = ["gcp"]
  }

  expect_failures = [var.hosted_zone_cloud_provider]
}

run "repeated_provider_is_rejected" {
  command = plan

  variables {
    hosted_zone_cloud_provider = ["aws", "aws"]
  }

  expect_failures = [var.hosted_zone_cloud_provider]
}

run "selected_aws_without_a_zone_is_rejected" {
  command = plan

  variables {
    hosted_zone_cloud_provider = ["aws"]
    aws_hosted_zone_name       = null
  }

  expect_failures = [var.hosted_zone_cloud_provider]
}

run "selected_azure_without_a_zone_is_rejected" {
  command = plan

  variables {
    hosted_zone_cloud_provider = ["azure"]
    azure_hosted_zone_name     = null
  }

  expect_failures = [var.hosted_zone_cloud_provider]
}

run "empty_zone_name_is_rejected" {
  command = plan

  variables {
    aws_hosted_zone_name = ""
  }

  expect_failures = [var.aws_hosted_zone_name]
}

run "zone_with_a_trailing_dot_is_rejected" {
  command = plan

  variables {
    azure_hosted_zone_name = "az.sujay-samanta.sbx.hashidemos.io."
  }

  expect_failures = [var.azure_hosted_zone_name]
}

run "empty_target_hostname_is_rejected" {
  command = plan

  variables {
    vault_target_hostname = ""
  }

  expect_failures = [var.vault_target_hostname]
}

run "target_hostname_with_a_scheme_is_rejected" {
  command = plan

  variables {
    vault_target_hostname = "https://vault-private.example.hashicorp.cloud"
  }

  expect_failures = [var.vault_target_hostname]
}
