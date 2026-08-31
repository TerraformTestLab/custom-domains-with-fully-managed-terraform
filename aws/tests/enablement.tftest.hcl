# Networking enablement matrix for the root module.
#
#   terraform init && terraform test
#
# All providers are mocked - no AWS/HCP credentials or network calls. Data
# sources that feed postconditions (HVN region, subnet VPC) or CIDR math get
# fixed values via mock_data defaults so only the enablement logic is exercised.
#
# The advisory `check` blocks in main.tf fire as designed in several scenarios.
# `terraform test` treats a failed check assertion as a run failure, so every
# run lists the checks it legitimately triggers in `expect_failures` - the list
# doubles as an assertion about which warnings an operator sees.

mock_provider "aws" {
  mock_data "aws_vpc" {
    defaults = {
      cidr_block = "10.0.0.0/16"
      cidr_block_associations = [{
        cidr_block     = "10.0.0.0/16"
        association_id = "vpc-cidr-assoc-0000000000000000"
        state          = "associated"
      }]
    }
  }
  mock_data "aws_subnet" {
    defaults = {
      vpc_id = "vpc-00000000000000000" # must equal var.vpc_id used below
    }
  }
  mock_data "aws_route_table" {
    defaults = { route_table_id = "rtb-00000000000000000" }
  }
  mock_data "aws_route53_zone" {
    defaults = { zone_id = "Z0000000000000000000Q" }
  }
}

mock_provider "hcp" {
  mock_data "hcp_hvn" {
    defaults = {
      cidr_block = "172.25.16.0/20"
      region     = "us-west-2"
      self_link  = "iam/hvn/self-link"
    }
  }
  mock_data "hcp_vault_cluster" {
    defaults = {
      vault_private_endpoint_url = "https://vault-private-abc.hcp.example:8200"
      vault_public_endpoint_url  = "https://vault-public-abc.hcp.example:8200"
    }
  }
  mock_data "hcp_aws_network_peering" {
    defaults = {
      self_link           = "iam/peering/self-link"
      provider_peering_id = "pcx-00000000000000000"
      state               = "ACTIVE"
    }
  }
}

mock_provider "tls" {}
mock_provider "local" {}

variables {
  aws_region               = "us-west-2"
  hcp_project_id           = "605075e7-938b-4ffb-b041-c36f3b58087b"
  route53_hosted_zone_name = "example.com"
  vault_record_name        = "vault"
  cluster_id               = "vault-cluster-test"
  hvn_id                   = "vault-hvn-test"
  create_cluster           = false
  vault_tier               = ""

  public_link             = false
  enable_vpn              = false
  create_hvn_peering      = false
  manage_peering_routes   = false
  existing_hvn_peering_id = ""
  vpc_id                  = ""
  subnet_id               = ""
  client_vpn_cidr         = ""
}

########################  root_preflight - required vars  ######################

run "public_link_unset_fails" {
  command = plan
  variables {
    public_link = null
  }
  expect_failures = [
    terraform_data.root_preflight,
    check.private_cluster_vpn_skipped,
    check.private_cluster_peering_skipped,
  ]
}

run "enable_vpn_unset_fails_on_private" {
  command = plan
  variables {
    public_link = false
    enable_vpn  = null
  }
  expect_failures = [
    terraform_data.root_preflight,
    check.private_cluster_peering_skipped,
  ]
}

run "create_hvn_peering_unset_fails_on_private" {
  command = plan
  variables {
    public_link        = false
    create_hvn_peering = null
  }
  expect_failures = [
    terraform_data.root_preflight,
    check.private_cluster_vpn_skipped,
    check.private_cluster_peering_skipped,
  ]
}

run "manage_peering_routes_unset_fails_when_peering" {
  command = plan
  variables {
    public_link           = false
    enable_vpn            = false
    create_hvn_peering    = true
    manage_peering_routes = null
    vpc_id                = "vpc-00000000000000000"
    subnet_id             = "subnet-00000000000000000"
  }
  expect_failures = [
    terraform_data.root_preflight,
    check.private_cluster_vpn_skipped,
    check.peering_routes_unmanaged,
  ]
}

########################  public cluster - everything skipped  #################

run "public_cluster_skips_networking_even_when_unset" {
  command = plan
  variables {
    public_link           = true
    enable_vpn            = null
    create_hvn_peering    = null
    manage_peering_routes = null
  }
  assert {
    condition     = output.vpn_enabled == false
    error_message = "public cluster must not enable the Client VPN"
  }
  assert {
    condition     = output.hvn_peering_enabled == false
    error_message = "public cluster must not manage HVN peering"
  }
}

run "public_cluster_ignores_set_peering_vars" {
  command = plan
  variables {
    public_link             = true
    enable_vpn              = true
    create_hvn_peering      = true
    manage_peering_routes   = true
    existing_hvn_peering_id = ""
  }
  assert {
    condition     = output.vpn_enabled == false && output.hvn_peering_enabled == false
    error_message = "public cluster must ignore enable_vpn / create_hvn_peering"
  }
  expect_failures = [check.public_cluster_networking_ignored]
}

########################  private cluster - VPN opt-in  #######################

run "private_vpn_opt_in" {
  command = plan
  variables {
    public_link           = false
    enable_vpn            = true
    create_hvn_peering    = false
    manage_peering_routes = false
    vpc_id                = "vpc-00000000000000000"
    subnet_id             = "subnet-00000000000000000"
    client_vpn_cidr       = "10.200.0.0/22"
  }
  assert {
    condition     = output.vpn_enabled == true
    error_message = "enable_vpn = true on a private cluster must create the Client VPN"
  }
  expect_failures = [check.private_cluster_peering_skipped]
}

run "private_vpn_opt_out" {
  command = plan
  variables {
    public_link           = false
    enable_vpn            = false
    create_hvn_peering    = false
    manage_peering_routes = false
  }
  assert {
    condition     = output.vpn_enabled == false
    error_message = "enable_vpn = false must skip the Client VPN without failing"
  }
  expect_failures = [
    check.private_cluster_vpn_skipped,
    check.private_cluster_peering_skipped,
  ]
}

########################  private cluster - peering  #########################

run "private_create_peering" {
  command = plan
  variables {
    public_link           = false
    enable_vpn            = false
    create_hvn_peering    = true
    manage_peering_routes = true
    vpc_id                = "vpc-00000000000000000"
    subnet_id             = "subnet-00000000000000000"
  }
  assert {
    condition     = output.hvn_peering_enabled == true && output.hvn_peering_adopted == false
    error_message = "create_hvn_peering = true must create a peering"
  }
  expect_failures = [check.private_cluster_vpn_skipped]
}

run "private_adopt_peering" {
  command = plan
  variables {
    public_link             = false
    enable_vpn              = false
    create_hvn_peering      = false
    existing_hvn_peering_id = "vault-vpc-peering"
    manage_peering_routes   = false
    vpc_id                  = "vpc-00000000000000000"
    subnet_id               = "subnet-00000000000000000"
  }
  assert {
    condition     = output.hvn_peering_enabled == true && output.hvn_peering_adopted == true
    error_message = "existing_hvn_peering_id set must adopt the peering"
  }
  expect_failures = [
    check.private_cluster_vpn_skipped,
    check.peering_routes_unmanaged,
  ]
}

run "private_external_connectivity_no_peering" {
  command = plan
  variables {
    public_link             = false
    enable_vpn              = false
    create_hvn_peering      = false
    existing_hvn_peering_id = ""
    manage_peering_routes   = null
  }
  assert {
    condition     = output.hvn_peering_enabled == false
    error_message = "neither create nor adopt => no peering, and no failure"
  }
  expect_failures = [
    check.private_cluster_vpn_skipped,
    check.private_cluster_peering_skipped,
  ]
}

run "private_routes_independent_of_create" {
  command = plan
  variables {
    public_link           = false
    enable_vpn            = false
    create_hvn_peering    = true
    manage_peering_routes = false
    vpc_id                = "vpc-00000000000000000"
    subnet_id             = "subnet-00000000000000000"
  }
  assert {
    condition     = output.hvn_peering_enabled == true
    error_message = "create_hvn_peering = true with manage_peering_routes = false must still plan"
  }
  expect_failures = [
    check.private_cluster_vpn_skipped,
    check.peering_routes_unmanaged,
  ]
}

########################  vault_record_name - locked to "vault"  ##############

# public_link = true keeps the private-cluster advisory checks quiet so the run
# isolates the vault_record_name validation.
run "vault_record_name_empty_fails" {
  command = plan
  variables {
    public_link       = true
    vault_record_name = ""
  }
  expect_failures = [var.vault_record_name]
}

run "vault_record_name_other_value_fails" {
  command = plan
  variables {
    public_link       = true
    vault_record_name = "vault-api"
  }
  expect_failures = [var.vault_record_name]
}

####  module-level negative tests - the child module is the root for the run  ##
# expect_failures can only target root-module checkables, so run each module
# directly via the run-block `module {}` override.

run "peering_create_and_existing_conflict_fails" {
  command = plan
  module {
    source = "./modules/vault-hvn-peering"
  }
  variables {
    hvn_id              = "vault-hvn-test"
    vpc_id              = "vpc-00000000000000000"
    subnet_id           = "subnet-00000000000000000"
    peer_vpc_region     = "us-west-2"
    create_peering      = true
    existing_peering_id = "vault-vpc-peering"
    manage_routes       = true
  }
  expect_failures = [var.existing_peering_id]
}

run "peering_missing_vpc_fails" {
  command = plan
  module {
    source = "./modules/vault-hvn-peering"
  }
  variables {
    hvn_id              = "vault-hvn-test"
    vpc_id              = ""
    subnet_id           = ""
    peer_vpc_region     = "us-west-2"
    create_peering      = true
    existing_peering_id = ""
    manage_routes       = true
  }
  expect_failures = [var.vpc_id, var.subnet_id]
}

run "peering_vpc_hvn_overlap_fails" {
  command = plan
  module {
    source = "./modules/vault-hvn-peering"
  }
  variables {
    hvn_id              = "vault-hvn-test"
    vpc_id              = "vpc-00000000000000000"
    subnet_id           = "subnet-00000000000000000"
    peer_vpc_region     = "us-west-2"
    create_peering      = true
    existing_peering_id = ""
    manage_routes       = true
  }
  override_data {
    target = data.aws_vpc.this
    values = {
      cidr_block = "172.25.0.0/16"
      cidr_block_associations = [{
        cidr_block     = "172.25.0.0/16"
        association_id = "vpc-cidr-assoc-0000000000000000"
        state          = "associated"
      }]
    }
  }
  expect_failures = [terraform_data.validations]
}

run "vpn_cidr_overlap_fails" {
  command = plan
  module {
    source = "./modules/vault-aws-client-vpn"
  }
  variables {
    vpc_id          = "vpc-00000000000000000"
    subnet_id       = "subnet-00000000000000000"
    vpc_cidr        = "10.0.0.0/16"
    hvn_cidr        = "172.25.16.0/20"
    client_vpn_cidr = "10.0.0.0/22" # inside 10.0.0.0/16 -> overlap, still /22
    vault_fqdn      = "vault.example.com"
  }
  expect_failures = [terraform_data.validations]
}

run "vpn_client_cidr_missing_fails" {
  command = plan
  module {
    source = "./modules/vault-aws-client-vpn"
  }
  variables {
    vpc_id          = "vpc-00000000000000000"
    subnet_id       = "subnet-00000000000000000"
    vpc_cidr        = "10.0.0.0/16"
    hvn_cidr        = "172.25.16.0/20"
    client_vpn_cidr = ""
    vault_fqdn      = "vault.example.com"
  }
  expect_failures = [var.client_vpn_cidr]
}
