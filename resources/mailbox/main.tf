data "aws_caller_identity" "this" {}

data "aws_route53_zone" "this" {
  name         = var.domain
  private_zone = false
}

resource "random_string" "five" {
  length  = 5
  upper   = true
  lower   = true
  numeric = true
  special = false
}

resource "aws_s3_bucket" "mail" {
  bucket        = lower("Bucket-${var.domain}-${random_string.five.result}")
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "mail" {
  bucket                  = aws_s3_bucket.mail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "ses_put" {
  statement {
    sid       = "AllowSESPuts"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.mail.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["ses.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:Referer"
      values   = [data.aws_caller_identity.this.account_id]
    }
  }
}

resource "aws_s3_bucket_policy" "mail" {
  bucket = aws_s3_bucket.mail.id
  policy = data.aws_iam_policy_document.ses_put.json
}

resource "aws_ses_domain_identity" "this" {
  domain = var.domain
}

resource "aws_ses_domain_identity_verification" "this" {
  domain     = aws_ses_domain_identity.this.id
  depends_on = [aws_route53_record.ses_verification]
}

resource "aws_ses_receipt_rule_set" "this" {
  rule_set_name = "default-receive"
}

resource "aws_ses_active_receipt_rule_set" "this" {
  rule_set_name = aws_ses_receipt_rule_set.this.rule_set_name
}

resource "aws_ses_receipt_rule" "per_address" {
  for_each      = toset(var.account_names)
  name          = "Ses-Rule-${each.value}-${var.domain}"
  rule_set_name = aws_ses_receipt_rule_set.this.rule_set_name
  enabled       = true

  recipients = ["${each.value}@${var.domain}"]

  s3_action {
    position    = 1
    bucket_name = aws_s3_bucket.mail.bucket
  }

  scan_enabled = true

  depends_on = [
    aws_ses_active_receipt_rule_set.this,
    aws_s3_bucket_policy.mail,
    aws_ses_domain_identity_verification.this
  ]
}

resource "aws_route53_record" "ses_verification" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = "_amazonses.${var.domain}"
  type    = "TXT"
  ttl     = 300
  records = [aws_ses_domain_identity.this.verification_token]
}


resource "aws_route53_record" "mx_inbound" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.domain
  type    = "MX"
  ttl     = 300
  records = ["10 inbound-smtp.us-east-1.amazonaws.com."]
}

output "emails" {
  value = [for acc in var.account_names : "${acc}@${var.domain}"]
}