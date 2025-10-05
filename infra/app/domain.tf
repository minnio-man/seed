# 
# ROUTE 53 DOMAIN ZONE
# Pre-existing domain zone
# 

data "aws_route53_zone" "domain" {
  name = "${var.zone_domain}."
}

variable "zone_domain" {
  type        = string
  description = "The hostname of the existing domain zone that we can register the domain in"
}

variable "domain" {
  type        = string
  description = "The hostname for the public application frontend"
}

# 
# CERTIFICATES
# 

resource "aws_acm_certificate" "sydney_certificate" {
  domain_name       = var.domain
  validation_method = "DNS"

  # It's recommended to specify create_before_destroy = true in a lifecycle block 
  # to replace a certificate which is currently in use (eg, by aws_lb_listener).
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Environment = terraform.workspace
  }
}


# 
# CERTIFICATE DNS VALIDATION
# 

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.sydney_certificate.domain_validation_options : dvo.domain_name => {
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
  zone_id         = data.aws_route53_zone.domain.zone_id
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.sydney_certificate.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
