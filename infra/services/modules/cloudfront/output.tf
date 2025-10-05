output "SIGNING_KEY_ID" {
  value = aws_cloudfront_public_key.upload_distribution_cloudfront_key.id
}

output "SIGNING_PRIVATE_KEY_SECRET" {
  value = aws_secretsmanager_secret.signing_private_key.arn
}

output "DOCUMENTS_HOSTNAME" {
  value = local.DOCUMENTS_HOSTNAME
}
