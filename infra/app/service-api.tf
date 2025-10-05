# 
# IAM 
# 

resource "aws_iam_role" "api_task_definition_iam_role" {
  name               = "${terraform.workspace}_api_task_definition_role"
  assume_role_policy = file("${path.module}/policies/ecs_task_role.json")

  tags = {
    Environment = terraform.workspace
  }
}

resource "aws_iam_role_policy" "api_task_definition_iam_role_policy" {
  name = "${terraform.workspace}-api_ecs_role_policy"
  role = aws_iam_role.api_task_definition_iam_role.id

  policy = file("${path.module}/policies/ecs_access.json")
}

# 
# LOGS
# 

resource "aws_cloudwatch_log_group" "api_cloudwatch_log_group" {
  name = "/ecs/${terraform.workspace}_api_logs"

  tags = {
    Environment = terraform.workspace
  }
}

# 
# TASKS
# 

variable "api_image" {
  type = string
}

resource "aws_secretsmanager_secret" "api_env" {
  name                    = "${terraform.workspace}-api-env"
  recovery_window_in_days = 0

  tags = {
    Environment = terraform.workspace
  }
}

resource "aws_secretsmanager_secret_version" "api_env_secret_version" {
  secret_id = aws_secretsmanager_secret.api_env.id
  secret_string = jsonencode({
    # ENV
    OPENAI_API_KEY = var.OPENAI_API_KEY
    # AUTH0
    AUTH0_CLIENT_ID       = var.AUTH0_CLIENT_ID
    AUTH0_CLIENT_SECRET   = var.AUTH0_CLIENT_SECRET
    AUTH0_SECRET          = var.AUTH0_SECRET
    AUTH0_ISSUER_BASE_URL = local.AUTH0_ISSUER_BASE_URL
    AUTH0_BASE_URL        = "https://${var.domain}"
    # AWS
    AWS_ACCESS_KEY_ID     = var.AWS_ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY = var.AWS_SECRET_ACCESS_KEY
    AWS_REGION            = "ap-southeast-2"
    AWS_DEFAULT_REGION    = "ap-southeast-2"

    # AWS RESOURCES
    POSTGRES_PRISMA_URL = "${data.tfe_outputs.services.values.DATABASE_URL}?connection_limit=20&pool_timeout=30"
    S3_UPLOAD_BUCKET    = data.tfe_outputs.services.values.S3_UPLOAD_BUCKET
    NEW_RELIC_API_KEY                 = var.NEW_RELIC_API_KEY,
    LANGCHAIN_API_KEY                 = var.LANGCHAIN_API_KEY,
  })
}

# Defines the api container task definition
resource "aws_ecs_task_definition" "api_container" {
  family = "${terraform.workspace}-api_container"

  container_definitions = templatefile("${path.module}/task-definitions/api.json", {
    IMAGE                   = var.api_image,
    AWSLOGS_REGION          = var.aws_region,
    CREWVIA_ENV             = var.CREWVIA_ENV,
    LANGCHAIN_TRACING_V2    = var.LANGCHAIN_TRACING_V2
    AWSLOGS                 = aws_cloudwatch_log_group.api_cloudwatch_log_group.name,
    ENV_SECRET              = aws_secretsmanager_secret.api_env.arn
    REDIS_HOST              = data.tfe_outputs.services.values.REDIS_HOST
    ACTION_EXECUTION_QUEUE  = data.tfe_outputs.services.values.ACTION_EXECUTION_QUEUE
    INGESTION_SPAWNER_QUEUE = data.tfe_outputs.services.values.INGESTION_SPAWNER_QUEUE
    INGESTION_TASK_QUEUE    = data.tfe_outputs.services.values.INGESTION_TASK_QUEUE
    API_EVENT_SOURCE          = var.API_EVENT_SOURCE
    CREWVIA_DOMAIN_EVENT_DETAIL_TYPE = var.CREWVIA_DOMAIN_EVENT_DETAIL_TYPE
    CREWVIA_TRIGGER_EVENT_QUEUE_NAME = data.tfe_outputs.services.values.CREWVIA_TRIGGER_EVENT_QUEUE_NAME
  })

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024

  execution_role_arn = aws_iam_role.api_task_definition_iam_role.arn
}


# 
# SERVICE
# 

resource "aws_ecs_service" "api" {
  name                       = "${terraform.workspace}-api"
  cluster                    = aws_ecs_cluster.app_cluster.id
  task_definition            = aws_ecs_task_definition.api_container.arn
  launch_type                = "FARGATE"
  desired_count              = 1
  deployment_maximum_percent = 300

  network_configuration {
    subnets          = data.tfe_outputs.services.values.private_subnets
    security_groups  = [aws_security_group.api_service_sg.id]
    assign_public_ip = false
  }

  service_connect_configuration {
    enabled   = true
    namespace = "private.crewvia"

    service {
      discovery_name = "api"
      port_name      = "service"
      client_alias {
        port     = 9000
        dns_name = "api.private.crewvia"
      }
    }
  }
}


resource "aws_security_group" "api_service_sg" {
  name        = "api_service_sg_${terraform.workspace}"
  description = "api Service Security Group"
  vpc_id      = data.aws_vpc.vpc.id

  ingress {
    from_port   = 9000
    to_port     = 9000
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

