############################################
# EventBridge → SQS (crewvia document uploaded)
############################################

# Discover account / partition / region (no hardcoded IDs)
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id      = data.aws_caller_identity.current.account_id
  partition       = data.aws_partition.current.partition
  default_bus_arn = "arn:${local.partition}:events:${var.AWS_DEFAULT_REGION}:${local.account_id}:event-bus/default"

  # Workspace-scoped names to keep rule/policy IDs unique per env
  trigger_event_rule_name = "${terraform.workspace}-trigger-event-rule"
  domain_event_rule_name = "${terraform.workspace}-domain-event-rule"
  bus_policy_statement_id     = "AllowAccountPutEvents-${terraform.workspace}"
}

# 1) Rule on the DEFAULT bus to match your Worker's event
resource "aws_cloudwatch_event_rule" "trigger_event_rule" {
  name           = local.trigger_event_rule_name
  event_bus_name = "default"

  event_pattern = jsonencode({
    "source"      : [var.API_EVENT_SOURCE],
    "detail-type" : [var.CREWVIA_TRIGGER_EVENT_DETAIL_TYPE],
  })
}

# 2) Target: send ONLY event.detail to your crewvia SQS queue
#    (Queue is defined in job_queue.tf: aws_sqs_queue.crewvia_workflow_trigger_queue)
resource "aws_cloudwatch_event_target" "to_crewvia_queue" {
  rule      = aws_cloudwatch_event_rule.trigger_event_rule.name
  arn       = aws_sqs_queue.crewvia_trigger_event_queue.arn
  target_id = "crewviaTriggerEventSqsTarget"

  # Cleaner payload for the consumer
  input_path = "$.detail"
}

# 3) Queue policy: allow EventBridge to SendMessage to the queue, scoped to THIS rule
data "aws_iam_policy_document" "trigger_event_queue_from_eventbridge" {
  statement {
    sid     = "AllowEventBridgeSendMessageFromRule"
    effect  = "Allow"
    actions = ["sqs:SendMessage"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    resources = [aws_sqs_queue.crewvia_trigger_event_queue.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_event_rule.trigger_event_rule.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "trigger_event_queue_attach" {
  queue_url = aws_sqs_queue.crewvia_trigger_event_queue.url
  policy    = data.aws_iam_policy_document.trigger_event_queue_from_eventbridge.json
}

# 1b) Rule on the DEFAULT bus to match your Worker's DOMAIN event
resource "aws_cloudwatch_event_rule" "domain_event_rule" {
  name           = local.domain_event_rule_name
  event_bus_name = "default"

  event_pattern = jsonencode({
    "source"      : [var.API_EVENT_SOURCE],
    "detail-type" : [var.CREWVIA_DOMAIN_EVENT_DETAIL_TYPE],
  })
}

# 2b) Target: send ONLY event.detail to your crewvia DOMAIN SQS queue
resource "aws_cloudwatch_event_target" "domain_to_crewvia_queue" {
  rule      = aws_cloudwatch_event_rule.domain_event_rule.name
  arn       = aws_sqs_queue.crewvia_domain_event_queue.arn
  target_id = "crewviaDomainEventSqsTarget"

  input_path = "$.detail"
}

# 3b) Queue policy: allow EventBridge to SendMessage to the DOMAIN queue, scoped to THIS rule
data "aws_iam_policy_document" "domain_event_queue_from_eventbridge" {
  statement {
    sid     = "AllowEventBridgeSendMessageFromDomainRule"
    effect  = "Allow"
    actions = ["sqs:SendMessage"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    resources = [aws_sqs_queue.crewvia_domain_event_queue.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_event_rule.domain_event_rule.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "domain_event_queue_attach" {
  queue_url = aws_sqs_queue.crewvia_domain_event_queue.url
  policy    = data.aws_iam_policy_document.domain_event_queue_from_eventbridge.json
}

# 4) Bus resource policy: allow principals in THIS ACCOUNT to PutEvents to the default bus
#    (lets your Worker publish without attaching an identity policy to it)
resource "aws_cloudwatch_event_bus_policy" "allow_account_putevents" {
  event_bus_name = "default"

  policy = jsonencode({
    Version: "2012-10-17",
    Statement: [{
      Sid: "AllowAccountPutEvents-${terraform.workspace}",
      Effect: "Allow",
      Principal: { "AWS": "arn:${local.partition}:iam::${local.account_id}:root" },
      Action: "events:PutEvents",
      Resource: local.default_bus_arn
    }]
  })
}

############################################
# Helpful outputs
############################################
output "CREWVIA_TRIGGER_EVENT_RULE_ARN" {
  value       = aws_cloudwatch_event_rule.trigger_event_rule.arn
  description = "ARN of the EventBridge rule routing document events to the crewvia queue"
}

output "CREWVIA_DOMAIN_EVENT_RULE_ARN" {
  value       = aws_cloudwatch_event_rule.domain_event_rule.arn
  description = "ARN of the EventBridge rule routing domain events to the crewvia domain queue"
}
