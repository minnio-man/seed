terraform {
  backend "remote" {
    organization = "crewvia"

    workspaces {
      name = "crewvia-shared-resources"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
}
