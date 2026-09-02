terraform {
  required_version = ">= 1.15.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    hcp = {
      source  = "hashicorp/hcp"
      version = "~> 0.114"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}
