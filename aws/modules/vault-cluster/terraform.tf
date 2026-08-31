terraform {
  required_version = ">= 1.15.4"

  required_providers {
    hcp = {
      source  = "hashicorp/hcp"
      version = "~> 0.114"
    }
  }
}
