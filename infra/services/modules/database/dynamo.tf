resource "aws_dynamodb_table" "events" {
  name           = "events"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "streamId"
  range_key      = "version"


  attribute {
    name = "streamId"
    type = "S"
  }

  attribute {
    name = "version"
    type = "N"
  }

  attribute {
    name = "eventDate"
    type = "S"
  }

  attribute {
    name = "eventId"
    type = "S"
  }

  attribute {
    name = "aggregateId"
    type = "S"
  }

  global_secondary_index {
    name               = "eventIdIndex"
    hash_key           = "eventDate"
    range_key          = "eventId"
    projection_type    = "ALL"
  }

  global_secondary_index {
    name               = "aggregate_id_index"
    hash_key           = "aggregateId"
    range_key      = "version"
    projection_type    = "ALL"
  }
}

resource "aws_dynamodb_table" "snapshots" {
  name           = "snapshots"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "streamId"
  range_key      = "version"

  attribute {
    name = "streamId"
    type = "S"
  }

  attribute {
    name = "version"
    type = "N"
  }

  attribute {
    name = "aggregateName"
    type = "S"
  }

  attribute {
    name = "latest"
    type = "S"
  }

  attribute {
    name = "aggregateId"
    type = "S"
  }

  global_secondary_index {
    name               = "aggregate_index"
    hash_key           = "aggregateName"
    range_key          = "latest"
    projection_type    = "ALL"
  }

  global_secondary_index {
    name               = "aggregate_id_index"
    hash_key           = "aggregateId"
    range_key      = "version"
    projection_type    = "ALL"
  }
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id       = var.vpc_id
  service_name = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"

  route_table_ids = var.private_route_table_ids

  tags = {
    Environment = terraform.workspace
  }
}

data "aws_iam_policy_document" "dynamodb_access_policy" {
  statement {
    sid       = "DenyAccessNotFromVPC"
    effect    = "Deny"
    actions   = ["dynamodb:*"]
    resources = ["arn:aws:dynamodb:*:*:table/*"]
    condition {
      test     = "StringNotEquals"
      variable = "aws:sourceVpce"
      values   = [aws_vpc_endpoint.dynamodb.id]
    }
  }
  statement {
    sid       = "AllowAccessFromVPC"
    effect    = "Allow"
    actions   = ["dynamodb:*"]
    resources = ["arn:aws:dynamodb:*:*:table/*"]
    condition {
      test     = "StringEquals"
      variable = "aws:sourceVpce"
      values   = [aws_vpc_endpoint.dynamodb.id]
    }
  }
}


resource "aws_iam_policy" "dynamodb_access_policy" {
  name        = "dynamodb-access-policy"
  description = "Policy to restrict DynamoDB access to VPC endpoint"
  policy      = data.aws_iam_policy_document.dynamodb_access_policy.json
}

# Output the table name and ARN
output "dynamodb_events_table_name" {
  value = aws_dynamodb_table.events.name
}

output "dynamodb_snapshots_table_arn" {
  value = aws_dynamodb_table.snapshots.arn
}
