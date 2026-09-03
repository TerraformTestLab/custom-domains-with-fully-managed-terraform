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
    defaults = {
      route_table_id = "rtb-00000000000000000"
      routes         = []
    }
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

# The HVN-routes lookup (data.http.hvn_routes, in the vault-hvn-peering module)
# that backs the adopt-existing-routes logic.
mock_provider "http" {
  mock_data "http" {
    defaults = {
      status_code   = 200
      response_body = "{\"routes\":[]}"
    }
  }
}

# The root reads HCP_API_ADDRESS / HCP_API_TOKEN from the environment through
# these and injects them into vault-hvn-peering; the mock makes both non-empty so
# terraform_data.peering_routes_preflight passes unless a run overrides it.
mock_provider "external" {
  mock_data "external" {
    defaults = { result = { value = "mock-token" } }
  }
}

variables {
  aws_region               = "us-west-2"
  hcp_project_id           = "605075e7-938b-4ffb-b041-c36f3b58087b"
  hcp_organization_id      = "7f0000aa-0000-4000-8000-000000000abc"
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
    # Ignored value + no HCP org / token: a public cluster never instantiates the
    # peering module, so the new plan-phase validations cannot block it.
    hcp_organization_id = ""
  }
  assert {
    condition     = output.vpn_enabled == false && output.hvn_peering_enabled == false
    error_message = "public cluster must ignore enable_vpn / create_hvn_peering"
  }
  expect_failures = [check.public_cluster_networking_ignored]
}

run "public_cluster_ignores_invalid_networking_ids" {
  command = plan
  variables {
    public_link = true
    # Values left at their terraform.tfvars placeholders: neither required nor
    # format-checked on a public cluster, so the plan must not fail on them.
    vpc_id          = "REPLACE_WITH_VPC_ID"
    subnet_id       = "REPLACE_WITH_SUBNET_ID"
    client_vpn_cidr = "REPLACE_WITH_CLIENT_VPN_CIDR"
  }
  assert {
    condition     = output.vpn_enabled == false && output.hvn_peering_enabled == false
    error_message = "public cluster must ignore networking inputs entirely"
  }
  assert {
    condition     = output.vpc_cidr == ""
    error_message = "public cluster must not resolve the VPC (vpc_id is ignored)"
  }
  # The values are still surfaced as an advisory warning, just not a hard error.
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
    hcp_organization_id = "7f0000aa-0000-4000-8000-000000000abc"
    hcp_project_id      = "605075e7-938b-4ffb-b041-c36f3b58087b"
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
    hcp_organization_id = "7f0000aa-0000-4000-8000-000000000abc"
    hcp_project_id      = "605075e7-938b-4ffb-b041-c36f3b58087b"
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
    hcp_organization_id = "7f0000aa-0000-4000-8000-000000000abc"
    hcp_project_id      = "605075e7-938b-4ffb-b041-c36f3b58087b"
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

####  adopt-existing-routes: plan-phase validations + detection  ##############

# manage_routes = true but no HCP organization ID -> the plan cannot read the
# HVN's existing routes.
run "peering_manage_routes_requires_hcp_organization_id" {
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
    hcp_organization_id = ""
    hcp_project_id      = "605075e7-938b-4ffb-b041-c36f3b58087b"
  }
  expect_failures = [terraform_data.validations]
}

# manage_peering_routes = true but HCP_API_TOKEN is empty in the environment.
# The env-var check lives in the root now, not the module.
run "peering_manage_routes_requires_hcp_api_token" {
  command = plan
  variables {
    public_link           = false
    enable_vpn            = false
    create_hvn_peering    = true
    manage_peering_routes = true
    vpc_id                = "vpc-00000000000000000"
    subnet_id             = "subnet-00000000000000000"
  }
  override_data {
    target = data.external.hcp_api_token[0]
    values = { result = { value = "" } }
  }
  expect_failures = [
    terraform_data.peering_routes_preflight,
    check.private_cluster_vpn_skipped,
  ]
}

# manage_peering_routes = true but HCP_API_ADDRESS is empty in the environment.
run "peering_manage_routes_requires_hcp_api_address" {
  command = plan
  variables {
    public_link           = false
    enable_vpn            = false
    create_hvn_peering    = true
    manage_peering_routes = true
    vpc_id                = "vpc-00000000000000000"
    subnet_id             = "subnet-00000000000000000"
  }
  override_data {
    target = data.external.hcp_api_address[0]
    values = { result = { value = "" } }
  }
  expect_failures = [
    terraform_data.peering_routes_preflight,
    check.private_cluster_vpn_skipped,
  ]
}

# An HVN route that already exists for the VPC CIDR and points at this peering is
# detected and reported for adoption - no duplicate-create failure.
run "peering_reports_existing_hvn_route_as_adopted" {
  command = plan
  module {
    source = "./modules/vault-hvn-peering"
  }
  variables {
    hvn_id              = "vault-hvn-test"
    vpc_id              = "vpc-00000000000000000"
    subnet_id           = "subnet-00000000000000000"
    peer_vpc_region     = "us-west-2"
    create_peering      = false
    existing_peering_id = "vault-vpc-peering"
    manage_routes       = true
    hcp_organization_id = "7f0000aa-0000-4000-8000-000000000abc"
    hcp_project_id      = "605075e7-938b-4ffb-b041-c36f3b58087b"
    hcp_api_address     = "api.hcp.to"
    hcp_api_token       = "mock-token"
  }
  override_data {
    target = data.http.hvn_routes[0]
    values = {
      status_code   = 200
      response_body = "{\"routes\":[{\"id\":\"portal-route-vpc\",\"destination\":\"10.0.0.0/16\",\"target\":{\"hvn_connection\":{\"id\":\"vault-vpc-peering\"}}}]}"
    }
  }
  assert {
    condition     = contains(output.hvn_routes_adopted, "10.0.0.0/16")
    error_message = "existing HVN route for the VPC CIDR pointing at this peering must be reported as adopted"
  }
  assert {
    condition     = output.hvn_route_imports["10.0.0.0/16"] == "605075e7-938b-4ffb-b041-c36f3b58087b:vault-hvn-test:portal-route-vpc"
    error_message = "hvn_route_imports must carry the {project}:{hvn}:{route_id} import ID"
  }
}

# An HVN route for the VPC CIDR that points at a different peering is not adopted
# - the plan fails rather than silently rewriting it.
run "peering_rejects_foreign_hvn_route" {
  command = plan
  module {
    source = "./modules/vault-hvn-peering"
  }
  variables {
    hvn_id              = "vault-hvn-test"
    vpc_id              = "vpc-00000000000000000"
    subnet_id           = "subnet-00000000000000000"
    peer_vpc_region     = "us-west-2"
    create_peering      = false
    existing_peering_id = "vault-vpc-peering"
    manage_routes       = true
    hcp_organization_id = "7f0000aa-0000-4000-8000-000000000abc"
    hcp_project_id      = "605075e7-938b-4ffb-b041-c36f3b58087b"
    hcp_api_address     = "api.hcp.to"
    hcp_api_token       = "mock-token"
  }
  override_data {
    target = data.http.hvn_routes[0]
    values = {
      status_code   = 200
      response_body = "{\"routes\":[{\"id\":\"r1\",\"destination\":\"10.0.0.0/16\",\"target\":{\"hvn_connection\":{\"id\":\"some-other-peering\"}}}]}"
    }
  }
  expect_failures = [terraform_data.validations]
}

# An AWS route to the HVN CIDR that already exists in the target route table and
# points at this peering connection is detected and reported for adoption.
run "peering_reports_existing_aws_route_as_adopted" {
  command = plan
  module {
    source = "./modules/vault-hvn-peering"
  }
  variables {
    hvn_id              = "vault-hvn-test"
    vpc_id              = "vpc-00000000000000000"
    subnet_id           = "subnet-00000000000000000"
    peer_vpc_region     = "us-west-2"
    create_peering      = false
    existing_peering_id = "vault-vpc-peering"
    manage_routes       = true
    hcp_organization_id = "7f0000aa-0000-4000-8000-000000000abc"
    hcp_project_id      = "605075e7-938b-4ffb-b041-c36f3b58087b"
    hcp_api_address     = "api.hcp.to"
    hcp_api_token       = "mock-token"
  }
  override_data {
    target = data.aws_route_table.targets["rtb-00000000000000000"]
    values = {
      route_table_id = "rtb-00000000000000000"
      routes = [{
        cidr_block                = "172.25.16.0/20"
        vpc_peering_connection_id = "pcx-00000000000000000"
      }]
    }
  }
  assert {
    condition     = contains(output.aws_routes_adopted, "rtb-00000000000000000")
    error_message = "existing AWS route to the HVN CIDR pointing at this peering must be reported as adopted"
  }
}

# An AWS route to the HVN CIDR that points at a different connection is not
# adopted - the plan fails.
run "peering_rejects_foreign_aws_route" {
  command = plan
  module {
    source = "./modules/vault-hvn-peering"
  }
  variables {
    hvn_id              = "vault-hvn-test"
    vpc_id              = "vpc-00000000000000000"
    subnet_id           = "subnet-00000000000000000"
    peer_vpc_region     = "us-west-2"
    create_peering      = false
    existing_peering_id = "vault-vpc-peering"
    manage_routes       = true
    hcp_organization_id = "7f0000aa-0000-4000-8000-000000000abc"
    hcp_project_id      = "605075e7-938b-4ffb-b041-c36f3b58087b"
    hcp_api_address     = "api.hcp.to"
    hcp_api_token       = "mock-token"
  }
  override_data {
    target = data.aws_route_table.targets["rtb-00000000000000000"]
    values = {
      route_table_id = "rtb-00000000000000000"
      routes = [{
        cidr_block                = "172.25.16.0/20"
        vpc_peering_connection_id = "pcx-99999999999999999"
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
