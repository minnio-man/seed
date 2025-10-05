locals {
  DATABASE_URL  = "postgresql://${aws_db_instance.service_db.username}:${data.aws_secretsmanager_secret_version.service_db_password_secret_value.secret_string}@${aws_db_instance.service_db.endpoint}/${aws_db_instance.service_db.db_name}"
  MIGRATION_URL = "postgresql://${aws_db_instance.service_db.username}:${data.aws_secretsmanager_secret_version.service_db_password_secret_value.secret_string}@localhost/${aws_db_instance.service_db.db_name}"
}

resource "random_password" "database" {
  special = false
  length  = 15
  keepers = {}
}

resource "aws_secretsmanager_secret" "service_db_password_secret" {
  name                    = "${terraform.workspace}--api-db-password"
  recovery_window_in_days = 0

  tags = {
    Environment = terraform.workspace
  }
}

resource "aws_secretsmanager_secret_version" "service_db_password_secret_version" {
  secret_id     = aws_secretsmanager_secret.service_db_password_secret.id
  secret_string = random_password.database.result
}

data "aws_secretsmanager_secret_version" "service_db_password_secret_value" {
  secret_id = aws_secretsmanager_secret.service_db_password_secret.id
  depends_on = [
    aws_secretsmanager_secret_version.service_db_password_secret_version
  ]
}

resource "random_uuid" "final_snapshot_identifier" {
  keepers = {}
}

resource "aws_db_subnet_group" "default" {
  name       = "crewvia-db"
  subnet_ids = var.subnet_ids

  tags = {
    Environment = terraform.workspace
  }
}

resource "aws_security_group" "db" {
  name        = "rds_sg_${terraform.workspace}"
  description = "RDS Security Group"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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

resource "aws_db_instance" "service_db" {
  allocated_storage         = 10
  apply_immediately         = true
  identifier                = "${terraform.workspace}-service"
  final_snapshot_identifier = "snap-${random_uuid.final_snapshot_identifier.result}"
  storage_type              = "gp2"
  engine                    = "postgres"
  engine_version            = "15.12"
  instance_class            = "db.t4g.medium"
  db_name                   = "application"
  username                  = var.username
  password                  = data.aws_secretsmanager_secret_version.service_db_password_secret_value.secret_string
  publicly_accessible       = false
  deletion_protection       = true
  db_subnet_group_name      = aws_db_subnet_group.default.name

  depends_on = [
    aws_secretsmanager_secret_version.service_db_password_secret_version,
    data.aws_secretsmanager_secret_version.service_db_password_secret_value
  ]
  vpc_security_group_ids = [aws_security_group.db.id]

  tags = {
    Environment = terraform.workspace
  }
}

data "aws_ami" "amazon-linux-2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-*-hvm-*-x86_64-gp2"]
  }
}

resource "aws_security_group" "bastion" {
  name        = "bastion_sg_${terraform.workspace}"
  description = "Bastion Security Group"
  vpc_id      = var.vpc_id

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    description      = "Allow traffic on all ports and ip ranges"
  }

  tags = {
    Environment = terraform.workspace
  }
}

resource "aws_instance" "bastion_host_ec2_instance" {
  ami                         = data.aws_ami.amazon-linux-2.id
  instance_type               = "t2.nano"
  subnet_id                   = var.bastion_subnet_id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  disable_api_termination     = true
  associate_public_ip_address = true
  key_name                    = "bastion"

  root_block_device {
    encrypted = true
  }

  monitoring = true

  tags = {
    Environment = terraform.workspace
  }
}

output "BASTION_IP" {
  value = aws_instance.bastion_host_ec2_instance.public_ip
}

output "DATABASE_NAME" {
  value = aws_db_instance.service_db.db_name
}

output "DATABASE_USERNAME" {
  value = aws_db_instance.service_db.username
}

output "DATABASE_PASSWORD" {
  value     = random_password.database.result
  sensitive = true
}

output "DATABASE_ENDPOINT" {
  value = aws_db_instance.service_db.endpoint
}

output "DATABASE_URL" {
  value     = local.DATABASE_URL
  sensitive = true
}

output "MIGRATION_URL" {
  value     = local.MIGRATION_URL
  sensitive = true
}
