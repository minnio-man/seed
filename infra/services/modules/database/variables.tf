variable "username" {
    type    = string
    default = "dbmaster"
}

variable "vpc_id" {
    type = string
}

variable "subnet_ids" {
    type = list(string)
}

variable "bastion_subnet_id" {
    type = string
}

variable "private_route_table_ids" {
  type = list(string)
}

variable "aws_region" {
  type = string
}
