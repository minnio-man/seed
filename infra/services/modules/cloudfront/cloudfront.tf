terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws, aws.apsoutheast2]
    }
  }
}

data "aws_s3_bucket" "bucket" {
  bucket   = var.bucket
  provider = aws.apsoutheast2
}

# resource "aws_s3_bucket_policy" "s3_frontend_bucket_policy" {
#   bucket   = data.aws_s3_bucket.bucket.id
#   policy   = data.aws_iam_policy_document.frontend_bucket_policy.json
#   provider = aws.apsoutheast2
# }

# data "aws_iam_policy_document" "frontend_bucket_policy" {
#   statement {
#     actions = [
#       "s3:GetObject",
#       "s3:ListBucket",
#     ]

#     principals {
#       type        = "AWS"
#       identifiers = [aws_cloudfront_distribution.uploads_bucket_dist.arn]
#     }

#     resources = [
#       data.aws_s3_bucket.bucket.arn,
#       "${data.aws_s3_bucket.bucket.arn}/*",
#     ]
#   }
# }

data "aws_iam_policy_document" "cloudfront_documents_access_policy" {
  statement {
    sid    = "AllowCloudFrontServicePrincipalReadOnly"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject",
    ]

    resources = [
      data.aws_s3_bucket.bucket.arn,
      "${data.aws_s3_bucket.bucket.arn}/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.uploads_bucket_dist.arn]
    }
  }
}

resource "aws_cloudfront_origin_access_control" "crewvia_documents_oac" {
  name                              = "crewvia-documents-oac"
  description                       = "Private Access Control"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}


resource "aws_s3_bucket_policy" "cloudfront_documents_access_policy" {
  bucket   = data.aws_s3_bucket.bucket.id
  policy   = data.aws_iam_policy_document.cloudfront_documents_access_policy.json
  provider = aws.apsoutheast2
}

resource "aws_acm_certificate" "cert" {
  depends_on                = [var.caa]
  domain_name               = var.APP_DOMAIN
  subject_alternative_names = ["*.${var.APP_DOMAIN}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

}

locals {
  DOCUMENTS_HOSTNAME = "documents.${var.APP_DOMAIN}"
}

resource "aws_route53_record" "cert_validation" {
  depends_on = [var.caa]

  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.zone_id
}


resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

resource "aws_secretsmanager_secret" "signing_private_key" {
  name        = "${terraform.workspace}--signing-private-key"
  description = "Private key for CloudFront trusted keygroup"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "signing_private_key_version" {
  secret_id     = aws_secretsmanager_secret.signing_private_key.id
  secret_string = var.SIGNING_PRIVATE_KEY
}

resource "aws_cloudfront_public_key" "upload_distribution_cloudfront_key" {
  encoded_key = var.SIGNING_PUBLIC_KEY
  name        = "cloudfront-key"
  lifecycle {
    ignore_changes        = [encoded_key]
    create_before_destroy = true
  }
}

resource "aws_cloudfront_key_group" "upload_distribution_cloudfront_key" {
  items = [aws_cloudfront_public_key.upload_distribution_cloudfront_key.id]
  name  = "cloudfront-key-group"
  lifecycle {
    ignore_changes = [items]
  }
}

resource "aws_cloudfront_distribution" "uploads_bucket_dist" {
  enabled             = true
  http_version        = "http2"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  aliases             = [local.DOCUMENTS_HOSTNAME]

  origin {
    domain_name              = data.aws_s3_bucket.bucket.bucket_regional_domain_name
    origin_id                = data.aws_s3_bucket.bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.crewvia_documents_oac.id
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }


  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  default_cache_behavior {
    allowed_methods            = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods             = ["HEAD", "GET"]
    trusted_key_groups         = [aws_cloudfront_key_group.upload_distribution_cloudfront_key.id]
    target_origin_id           = data.aws_s3_bucket.bucket.bucket_regional_domain_name
    viewer_protocol_policy     = "redirect-to-https"
    response_headers_policy_id = aws_cloudfront_response_headers_policy.uploads.id

    forwarded_values {
      cookies {
        forward = "all"
      }

      query_string = true
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cert.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.1_2016"
  }
}

# resource "aws_shield_protection" "uploads" {
#   name         = "uploads-cloudfront-shield"
#   resource_arn = aws_cloudfront_distribution.uploads_bucket_dist.arn

#   tags = {
#     Environment = terraform.workspace
#   }
# }

resource "aws_cloudfront_response_headers_policy" "uploads" {
  name = "${terraform.workspace}_uploads_bucket_dist_response_headers_policy"

  cors_config {
    access_control_allow_credentials = false

    access_control_allow_headers {
      items = ["*"]
    }

    access_control_allow_methods {
      items = ["GET"]
    }

    access_control_allow_origins {
      items = ["localhost", "localhost:*", var.APP_DOMAIN, "*.${var.APP_DOMAIN}"]
    }

    origin_override = true
  }
}


resource "aws_route53_record" "documents" {
  zone_id = var.zone_id
  name    = local.DOCUMENTS_HOSTNAME
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.uploads_bucket_dist.domain_name
    zone_id                = aws_cloudfront_distribution.uploads_bucket_dist.hosted_zone_id
    evaluate_target_health = false
  }
}


