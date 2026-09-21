# Plan-time behaviour of the Azure resource groups, VNet and DNS zones.
#
#   terraform init -backend=false && terraform test
#
# Both providers are mocked, so no Azure or AWS credentials or network calls are
# needed. `-backend=false` skips the HCP Terraform `cloud` block in backend.tf.

mock_provider "azurerm" {}

mock_provider "aws" {
  mock_data "aws_route53_zone" {
    defaults = {
      zone_id = "Z0000000000000000000"
    }
  }
}

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  location        = "westus2"
  dns_zones = {
    hashidemos = {
      parent_zone_name = "sujay-samanta.sbx.hashidemos.io"
      child_label      = "az"
    }
    hashicorpdemo = {
      parent_zone_name = "sujay-samanta.aws.sbx.hashicorpdemo.com"
      child_label      = "az"
    }
  }
}

run "defaults_create_three_groups_the_vnet_and_both_dns_zones" {
  command = plan

  assert {
    condition     = module.resource_groups.names == { network = "rg-network-westus2", vault_access = "rg-vault-access-westus2", dns = "rg-dns" }
    error_message = "Expected the default resource group names."
  }

  assert {
    condition     = module.vnet.name == "vcs-vnet" && module.vnet.address_space == toset(["10.0.0.0/16"])
    error_message = "Expected the default VNet."
  }

  assert {
    condition     = module.dns_zones.zones.hashidemos.name == "az.sujay-samanta.sbx.hashidemos.io"
    error_message = "Expected the az child zone under the hashidemos.io parent."
  }

  assert {
    condition     = module.dns_zones.zones.hashicorpdemo.name == "az.sujay-samanta.aws.sbx.hashicorpdemo.com"
    error_message = "Expected the az child zone under the hashicorpdemo.com parent."
  }
}

run "each_zone_is_delegated_with_an_ns_record_in_its_own_parent" {
  command = plan

  assert {
    condition     = alltrue([for record in values(module.dns_zones.delegations) : record.type == "NS"])
    error_message = "Every delegation record must be an NS record."
  }

  assert {
    condition     = module.dns_zones.delegations["hashidemos"].name == "az.sujay-samanta.sbx.hashidemos.io" && module.dns_zones.delegations["hashicorpdemo"].name == "az.sujay-samanta.aws.sbx.hashicorpdemo.com"
    error_message = "Each NS record must be named after its own child zone."
  }
}

run "resource_group_names_can_be_overridden" {
  command = plan

  variables {
    resource_group_names = {
      network = "custom-network"
    }
  }

  assert {
    condition     = module.resource_groups.names == { network = "custom-network", vault_access = "rg-vault-access-westus2", dns = "rg-dns" }
    error_message = "Only the overridden group name should change."
  }
}

run "subnet_outside_address_space_is_rejected" {
  command = plan

  variables {
    workload_subnet_cidr = "192.168.1.0/24"
  }

  expect_failures = [var.workload_subnet_cidr]
}

run "malformed_workload_subnet_cidr_is_rejected" {
  command = plan

  variables {
    workload_subnet_cidr = "not-a-cidr"
  }

  expect_failures = [var.workload_subnet_cidr]
}

run "malformed_address_space_is_rejected" {
  command = plan

  variables {
    virtual_network_address_space = ["10.0.0.0/33"]
  }

  expect_failures = [var.virtual_network_address_space]
}

run "invalid_dns_child_label_is_rejected" {
  command = plan

  variables {
    dns_zones = {
      hashidemos = {
        parent_zone_name = "sujay-samanta.sbx.hashidemos.io"
        child_label      = "Not.A.Label"
      }
    }
  }

  expect_failures = [var.dns_zones]
}

run "parent_zone_with_trailing_dot_is_rejected" {
  command = plan

  variables {
    dns_zones = {
      hashidemos = {
        parent_zone_name = "sujay-samanta.sbx.hashidemos.io."
        child_label      = "az"
      }
    }
  }

  expect_failures = [var.dns_zones]
}
