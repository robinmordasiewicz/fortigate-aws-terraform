terraform {
  required_version = ">= 0.12"
  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "4.0.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.2"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "5.62.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.1"
    }
    external = {
      source  = "hashicorp/external"
      version = "2.3.3"
    }
    template = {
      source  = "hashicorp/template"
      version = "2.2.0"
    }
  }
}
provider "tls" {}
provider "external" {}
provider "local" {}
provider "aws" {
  region = var.aws_region
}
provider "template" {}
