terraform {
  /*
  backend "remote" {
    organization = "crewvia"

    workspaces {
      prefix = "crewvia-services-"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
  }
  */
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

provider "aws" {
  alias  = "east"
  region = "us-east-1"
}


module "database" {
  source = "./modules/database"
  count  = var.LOCALSTACK ? 0 : 1

  username          = var.DATABASE_USERNAME
  vpc_id            = aws_vpc.vpc.id
  bastion_subnet_id = aws_subnet.public_subnet_a.id
  subnet_ids = [
    aws_subnet.private_subnet[0].id,
    aws_subnet.private_subnet[1].id,
  ]
  
  # dynamo stuff
  aws_region = var.aws_region
  private_route_table_ids = [aws_route_table.private[0].id]
}

output "DATABASE_NAME" {
  value = length(module.database) > 0 ? module.database[0].DATABASE_NAME : null
}

output "DATABASE_USERNAME" {
  value = length(module.database) > 0 ? module.database[0].DATABASE_USERNAME : null
}

output "DATABASE_PASSWORD" {
  value     = length(module.database) > 0 ? module.database[0].DATABASE_PASSWORD : null
  sensitive = true
}

output "DATABASE_ENDPOINT" {
  value = length(module.database) > 0 ? module.database[0].DATABASE_ENDPOINT : null
}

output "DATABASE_URL" {
  value     = length(module.database) > 0 ? module.database[0].DATABASE_URL : null
  sensitive = true
}

output "MIGRATION_URL" {
  value     = length(module.database) > 0 ? module.database[0].MIGRATION_URL : null
  sensitive = true
}

output "BASTION_IP" {
  value     = length(module.database) > 0 ? module.database[0].BASTION_IP : null
}


module "elasticache" {
  source = "./modules/elasticache"
  count  = var.LOCALSTACK ? 0 : 1

  vpc_id  = aws_vpc.vpc.id
  subnets = [aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_b.id]
}

output "REDIS_HOST" {
  value = length(module.elasticache) > 0 ? module.elasticache[0].REDIS_HOST : null
}


module "documents-cf" {
  source = "./modules/cloudfront"
  providers = {
    aws              = aws.east
    aws.apsoutheast2 = aws
  }

  count   = var.LOCALSTACK ? 0 : 1
  caa     = var.LOCALSTACK ? null : aws_route53_record.caa[0].id
  zone_id = var.LOCALSTACK ? null : data.aws_route53_zone.application_dns_zone[0].id
  bucket  = aws_s3_bucket.uploads.id

  APP_DOMAIN          = var.APP_DOMAIN
  SIGNING_PUBLIC_KEY  = var.SIGNING_PUBLIC_KEY
  SIGNING_PRIVATE_KEY = var.SIGNING_PRIVATE_KEY
}

output "SIGNING_KEY_ID" {
  value = length(module.documents-cf) > 0 ? module.documents-cf[0].SIGNING_KEY_ID : null
}

output "SIGNING_PRIVATE_KEY_SECRET" {
  value = length(module.documents-cf) > 0 ? module.documents-cf[0].SIGNING_PRIVATE_KEY_SECRET : null
}

output "DOCUMENTS_HOSTNAME" {
  value = length(module.documents-cf) > 0 ? module.documents-cf[0].DOCUMENTS_HOSTNAME : null
}
