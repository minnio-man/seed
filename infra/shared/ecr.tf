# ECR

resource "aws_ecr_repository" "container_repository" {
  name = "${terraform.workspace}_ecr"

  tags = {
    Environment = "${terraform.workspace}"
  }
}

resource "aws_ecr_lifecycle_policy" "lifecycle_policy" {
  repository = aws_ecr_repository.container_repository.name

  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep last 20 images",
            "selection": {
                "tagStatus": "tagged",
                "tagPrefixList": ["application_"],
                "countType": "imageCountMoreThan",
                "countNumber": 20
            },
            "action": {
                "type": "expire"
            }
        },
        {
            "rulePriority": 2,
            "description": "Keep last 20 images",
            "selection": {
                "tagStatus": "tagged",
                "tagPrefixList": ["worker_"],
                "countType": "imageCountMoreThan",
                "countNumber": 20
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}


resource "aws_iam_user" "ci_user" {
  name = "${terraform.workspace}_ci_user"
  path = "/"

  tags = {
    Environment = "${terraform.workspace}"
  }
}

resource "aws_iam_access_key" "ci_user" {
  user = aws_iam_user.ci_user.name
}

data "aws_iam_policy_document" "ci_user_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:GetDownloadUrlForLayer"
    ]
    resources = [aws_ecr_repository.container_repository.arn, "${aws_ecr_repository.container_repository.arn}/*"]
  }
}

resource "aws_iam_user_policy" "ci_user_policy" {
  name   = "ci_user"
  user   = aws_iam_user.ci_user.name
  policy = data.aws_iam_policy_document.ci_user_policy.json
}

resource "aws_ecr_repository_policy" "shared_ecr_policy" {
  repository = aws_ecr_repository.container_repository.name

  policy = jsonencode({
    Version = "2008-10-17"
    Statement = [
      {
        Sid    = "AllowCrossAccountPull"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::767397685767:root",
          ]
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:GetAuthorizationToken"
        ]
      }
    ]
  })
}



# OUTPUTS

output "ECR_REPOSITORY_URL" {
  value = aws_ecr_repository.container_repository.repository_url
}

output "ECR_REPOSITORY_NAME" {
  value = aws_ecr_repository.container_repository.name
}

output "CI_USER_ACCESS_KEY_ID" {
  value = aws_iam_access_key.ci_user.id
}

output "CI_USER_ACCESS_KEY_SECRET" {
  value     = aws_iam_access_key.ci_user.secret
  sensitive = true
}
