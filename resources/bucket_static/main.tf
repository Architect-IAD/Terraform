terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

variable "bucket_name" {
  type = string
}

resource "random_string" "five" {
  length  = 5
  upper   = true
  lower   = true
  numeric = true
  special = false
}

variable "accessors" {
  type = list(object({
    role_name = string
    actions   = list(string)
  }))
}

locals {
  bucket_name = lower("Bucket-${var.bucket_name}-${random_string.five.result}")
}

resource "aws_s3_bucket" "default" {
  bucket        = local.bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "default" {
  bucket                  = aws_s3_bucket.default.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "CF → S3 access"
}

data "aws_iam_policy_document" "s3_read_from_cf" {
  statement {
    sid       = "AllowCloudFrontRead"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.default.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.oai.iam_arn]
    }
  }
}

resource "aws_iam_policy" "accessors" {
  for_each = { for i, v in var.accessors : i => v }
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : each.value.actions,
        "Resource" : [
          "${aws_s3_bucket.default.arn}/*"
        ]
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_accessors" {
  for_each   = { for i, v in var.accessors : i => v }
  role       = each.value.role_name
  policy_arn = aws_iam_policy.accessors[each.key].arn
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.default.id
  policy = data.aws_iam_policy_document.s3_read_from_cf.json
}

output "cf_config" {
  value = {
    name   = local.bucket_name
    domain = aws_s3_bucket.default.bucket_regional_domain_name
    oai_id = aws_cloudfront_origin_access_identity.oai.id
  }
}