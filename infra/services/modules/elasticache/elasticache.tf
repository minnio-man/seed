variable "vpc_id" {
  type = string
}

variable "subnets" {
  type = list(string)
}

data "aws_vpc" "vpc" {
  id = var.vpc_id
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id         = "${terraform.workspace}-redis"
  engine             = "redis"
  node_type          = "cache.t4g.micro"
  num_cache_nodes    = 1
  port               = 6379
  subnet_group_name  = aws_elasticache_subnet_group.subnet_group.name
  security_group_ids = [aws_security_group.redis_sg.id]
  apply_immediately  = true
}

resource "aws_elasticache_subnet_group" "subnet_group" {
  name       = "${terraform.workspace}-elasticache-subnet-group"
  subnet_ids = var.subnets
}

resource "aws_security_group" "redis_sg" {
  name        = "redis_sg_${terraform.workspace}"
  description = "Redis Security Group"
  vpc_id      = data.aws_vpc.vpc.id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = terraform.workspace
  }
}

output "REDIS_HOST" {
  value = aws_elasticache_cluster.redis.cache_nodes.0.address
}
