variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.0.0.0/24"
}

variable "private_subnet_cidr" {
  type    = string
  default = "10.0.129.0/24"
}

variable "aws_region" {
  type    = string
  default = "ap-southeast-2"
}


# VPC 

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Environment = terraform.workspace
  }
}

resource "aws_service_discovery_http_namespace" "services" {
  name        = "private.crewvia"
  description = "private"

  count = var.LOCALSTACK ? 0 : 1

  tags = {
    Environment = terraform.workspace
  }
}

# INTERNET GATEWAY

resource "aws_internet_gateway" "internet_gw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Environment = terraform.workspace
  }
}

resource "aws_route" "ig_route" {
  route_table_id         = aws_vpc.vpc.default_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.internet_gw.id
}



resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gw.id
  }

  tags = {
    Environment = terraform.workspace
  }
}

# PUBLIC SUBNET

resource "aws_subnet" "public_subnet_a" {
  vpc_id = aws_vpc.vpc.id

  cidr_block        = cidrsubnet(var.public_subnet_cidr, 2, 0)
  availability_zone = "${var.aws_region}a"

  tags = {
    Environment = terraform.workspace
  }
}

resource "aws_subnet" "public_subnet_b" {
  vpc_id = aws_vpc.vpc.id

  cidr_block        = cidrsubnet(var.public_subnet_cidr, 2, 2)
  availability_zone = "${var.aws_region}b"

  tags = {
    Environment = terraform.workspace
  }
}

variable "azs" {
  type    = list(string)
  default = ["ap-southeast-2a", "ap-southeast-2b"]
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_subnet_a.id
  depends_on    = [aws_internet_gateway.internet_gw]

  tags = {
    Environment = terraform.workspace
  }
}

resource "aws_route_table" "private" {
  count  = length(var.azs)
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route" "private" {
  count                  = length(compact(var.azs))
  route_table_id         = element(aws_route_table.private.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.nat.*.id, count.index)
}

resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.vpc.id
  count      = length(var.azs)
  cidr_block = cidrsubnet(var.private_subnet_cidr, 2, count.index * 2)
  availability_zone = element(var.azs, count.index)

  tags = {
    Environment = terraform.workspace
  }
}

resource "aws_route_table_association" "private" {
  count          = length(var.azs)
  subnet_id      = element(aws_subnet.private_subnet.*.id, count.index)
  route_table_id = element(aws_route_table.private.*.id, count.index)
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_route_table_association" "public_subnet_a_route_table" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_subnet_b_route_table" {
  subnet_id      = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.public_route_table.id
}

output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "public_subnets" {
  value = [
    aws_subnet.public_subnet_a.id,
    aws_subnet.public_subnet_b.id,
  ]
}

output "private_subnets" {
  value = [
    aws_subnet.private_subnet[0].id,
    aws_subnet.private_subnet[1].id,
  ]
}

