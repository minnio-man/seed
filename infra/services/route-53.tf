variable "APP_DOMAIN" {
  type = string
}

# ZONE TO HOUSE ALL RECORDS
data "aws_route53_zone" "application_dns_zone" {
  name  = var.APP_DOMAIN
  count = var.LOCALSTACK ? 0 : 1
}

resource "aws_route53_record" "caa" {
  name    = var.APP_DOMAIN
  type    = "CAA"
  zone_id = data.aws_route53_zone.application_dns_zone[0].id
  ttl     = 60
  records = ["0 issue \"letsencrypt.org\"", "0 issue \"amazon.com\""]
  count   = var.LOCALSTACK ? 0 : 1
}


