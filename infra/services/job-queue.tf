# QUEUES
locals {
  # TRAVIS: EVENT BRIDGE event & trigger target queue
  CREWVIA_DOMAIN_EVENT_QUEUE_NAME                  = "${terraform.workspace}-crewvia-domain-event-queue"
  CREWVIA_TRIGGER_EVENT_QUEUE_NAME                  = "${terraform.workspace}-crewvia-trigger-event-queue"
}


# crewvia/trigger-event target queue
resource "aws_sqs_queue" "crewvia_domain_event_queue" {
  name                       = local.CREWVIA_DOMAIN_EVENT_QUEUE_NAME
  delay_seconds              = 0
  visibility_timeout_seconds = 60
  max_message_size           = 262144  # bytes (256 KB)
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 10
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.crewvia_trigger_event_deadletter_queue.arn
    maxReceiveCount     = 4
  })
}

resource "aws_sqs_queue" "crewvia_domain_event_deadletter_queue" {
  name                       = "${local.CREWVIA_DOMAIN_EVENT_QUEUE_NAME}-deadletter"
  delay_seconds              = 0
  visibility_timeout_seconds = 60
  max_message_size           = 262144  # bytes (256 KB)
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 10
}

# crewvia/trigger-event target queue
resource "aws_sqs_queue" "crewvia_trigger_event_queue" {
  name                       = local.CREWVIA_TRIGGER_EVENT_QUEUE_NAME
  delay_seconds              = 0
  visibility_timeout_seconds = 60
  max_message_size           = 262144  # bytes (256 KB)
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 10
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.crewvia_trigger_event_deadletter_queue.arn
    maxReceiveCount     = 4
  })
}

resource "aws_sqs_queue" "crewvia_trigger_event_deadletter_queue" {
  name                       = "${local.CREWVIA_TRIGGER_EVENT_QUEUE_NAME}-deadletter"
  delay_seconds              = 0
  visibility_timeout_seconds = 60
  max_message_size           = 262144  # bytes (256 KB)
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 10
}

# OUTPUTS

output "CREWVIA_DOMAIN_EVENT_QUEUE" {
  value       = aws_sqs_queue.crewvia_domain_event_queue.url
  description = "The SQS queue responsible for crewvia domain events"
}

output "CREWVIA_TRIGGER_EVENT_QUEUE" {
  value       = aws_sqs_queue.crewvia_trigger_event_queue.url
  description = "The SQS queue responsible for crewvia trigger events"
}

output "CREWVIA_DOMAIN_EVENT_QUEUE_NAME" {
  value       = aws_sqs_queue.crewvia_domain_event_queue.arn
  description = "The SQS queue responsible for crewvia domain events"
}

output "CREWVIA_TRIGGER_EVENT_QUEUE_NAME" {
  value       = aws_sqs_queue.crewvia_trigger_event_queue.arn
  description = "The SQS queue responsible for crewvia workflow triggers"
}

