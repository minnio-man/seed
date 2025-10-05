terraform {
  backend "remote" {
    organization = "crewvia"

    workspaces {
      prefix = "crewvia-application-"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    vercel = {
      source  = "vercel/vercel"
      version = "~> 1.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

provider "aws" {
  alias  = "east"
  region = "us-east-1"
}


data "tfe_outputs" "services" {
  organization = "crewvia"
  workspace    = replace(terraform.workspace, "application", "services")
}

locals {
  AUTH0_ISSUER_BASE_URL = "https://${var.AUTH0_DOMAIN}"
}

variable "AUTH0_CLIENT_ID" {
  type = string
}

variable "CREWVIA_ENV" {
  type = string
}

variable "AUTH0_CLIENT_SECRET" {
  type = string
}

variable "AUTH0_DOMAIN" {
  type = string
}

variable "AUTH0_SECRET" {
  type = string
}

variable "OPENAI_API_KEY" {
  type      = string
  sensitive = true
}

variable "AWS_ACCESS_KEY_ID" {
  type = string
}

variable "AWS_SECRET_ACCESS_KEY" {
  type      = string
  sensitive = true
}

variable "APP_DOMAIN" {
  type = string
}

variable "EMAIL_FROM_ADDRESS" {
  type = string
}

variable "aws_region" {
  type    = string
  default = "ap-southeast-2"
}

data "aws_vpc" "vpc" {
  id = data.tfe_outputs.services.values.vpc_id
}

variable "LANGCHAIN_TRACING_V2" {
  type = bool
}

variable "LANGCHAIN_API_KEY" {
  type      = string
  sensitive = true
}

variable "AUTH0_CONNECTION_ID" {
  type = string
}

variable "AUTH0_MANAGEMENT_DOMAIN" {
  type = string
}

variable "NEW_RELIC_API_KEY" {
  type      = string
  sensitive = true
}

variable "API_EVENT_SOURCE" {
  type = string
  description = "EventBridge source string published by the Worker / Required for routing"
  default = "@jptr/crewvia-api"
}

variable "CREWVIA_DOMAIN_EVENT_DETAIL_TYPE" {
  type = string
  description = "EventBridge detail-type for the event / Required for routing"
  default = "crewvia/domain-event"
}

variable "CREWVIA_TRIGGER_EVENT_DETAIL_TYPE" {
  type = string
  description = "EventBridge detail-type for the event / Required for routing"
  default = "crewvia/trigger-event"
}