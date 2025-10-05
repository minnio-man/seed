variable "DATABASE_USERNAME" {
  type    = string
  default = "dbmaster"
}

# AWS

variable "AWS_ACCESS_KEY_ID" {
  type = string
}

variable "AWS_SECRET_ACCESS_KEY" {
  type      = string
  sensitive = true
}

variable "AWS_DEFAULT_REGION" {
  type    = string
  default = "ap-southeast-2"
}

# LOCALSTACK

variable "LOCALSTACK" {
  type        = bool
  default     = false
  description = "Whether applying in Localstack environment"
}

# 

variable "SIGNING_PRIVATE_KEY" {
  type      = string
  sensitive = true
}

variable "SIGNING_PUBLIC_KEY" {
  type = string
  sensitive = true
}

# Adjust these if your Worker publishes different values
variable "API_EVENT_SOURCE" {
  type        = string
  description = "EventBridge source string published by the API"
  default     = "@minnio/crewvia-api"
}

variable "CREWVIA_DOMAIN_EVENT_DETAIL_TYPE" {
  type        = string
  description = "EventBridge detail-type for the event"
  default     = "crewvia/domain-event"
}


variable "CREWVIA_TRIGGER_EVENT_DETAIL_TYPE" {
  type        = string
  description = "EventBridge detail-type for the event"
  default     = "crewvia/trigger-event"
}

