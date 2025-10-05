# DATABASE

moved {
  from = aws_secretsmanager_secret.service_db_password_secret
  to   = module.database[0].aws_secretsmanager_secret.service_db_password_secret
}

moved {
  from = aws_db_instance.service_db
  to   = module.database[0].aws_db_instance.service_db
}


# CLOUDFRONT

moved {
  from = aws_s3_bucket_policy.s3_frontend_bucket_policy
  to   = module.documents-cf[0].aws_s3_bucket_policy.s3_frontend_bucket_policy
}

moved {
  from = aws_cloudfront_public_key.upload_distribution_cloudfront_key
  to   = module.documents-cf[0].aws_cloudfront_public_key.upload_distribution_cloudfront_key
}

moved {
  from = aws_cloudfront_response_headers_policy.uploads
  to   = module.documents-cf[0].aws_cloudfront_response_headers_policy.uploads
}

#  ELASTICACHE

moved {
  from = aws_elasticache_subnet_group.subnet_group
  to   = module.elasticache[0].aws_elasticache_subnet_group.subnet_group
}

moved {
  from = aws_security_group.redis_sg
  to   = module.elasticache[0].aws_security_group.redis_sg
}
