# CLUSTER

resource "aws_ecs_cluster" "app_cluster" {
  name = "${terraform.workspace}_application"

  tags = {
    Environment = "${terraform.workspace}"
  }
}

