resource "aws_s3_bucket" "uploads" {
  bucket = "${terraform.workspace}-crewvia-uploads"

  tags = {
    Environment = "${terraform.workspace}"
  }
}

resource "aws_s3_bucket_cors_configuration" "example" {
  bucket = aws_s3_bucket.uploads.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["http://localhost:3000"]
  }

  count = var.LOCALSTACK ? 1 : 0
}

resource "aws_s3_bucket_ownership_controls" "uploads" {
  bucket = aws_s3_bucket.uploads.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_acl" "uploads" {
  depends_on = [
    aws_s3_bucket_ownership_controls.uploads,
    aws_s3_bucket_public_access_block.uploads,
  ]

  bucket = aws_s3_bucket.uploads.id
  acl    = "private"
}

locals {
  S3_UPLOAD_BUCKET = aws_s3_bucket.uploads.bucket
}

output "S3_UPLOAD_BUCKET" {
  value = local.S3_UPLOAD_BUCKET
}
