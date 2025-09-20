locals {
  cf_name = "${var.settings.prefix}-${var.cdn_name}"
  buckets = [for r in var.resources : r if r.type == "bucket"]
  lambda  = [for r in var.resources : r if r.type == "lambda"]
  default = [for r in var.resources : r if r.default][0]
}

data "aws_s3_bucket" "bucket" {
  for_each = local.buckets
  bucket   = each.value.name
}

resource "aws_cloudfront_origin_access_identity" "oai" {
  count   = local.buckets.length > 0 ? 1 : 0
  comment = "CF → S3 access"
}

resource "aws_s3_bucket_policy" "cf_read" {
  for_each = local.buckets
  bucket   = each.value.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowCloudFrontAccess"
      Effect = "Allow"
      Principal = {
        CanonicalUser = aws_cloudfront_origin_access_identity.oai[0].s3_canonical_user_id
      }
      Action   = ["s3:GetObject"]
      Resource = "${each.value.arn}/*"
    }]
  })
}

resource "aws_cloudfront_cache_policy" "cache" {
  for_each = var.resources
  name     = "${each.name}-cache-policy"

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_gzip = true

    cookies_config {
      cookie_behavior = "all"
    }

    headers_config {
      header_behavior = "none"
    }

    query_strings_config {
      query_string_behavior = "all"
    }
  }
}

resource "aws_cloudfront_distribution" "cdn" {
  enabled = true
  comment = local.cf_name

  dynamic "origin" {
    for_each = local.buckets
    content {
      origin_id                = "${each.name}-origin"
      domain_name              = data.aws_s3_bucket.bucket[each.key].bucket_regional_domain_name
      origin_access_control_id = aws_cloudfront_origin_access_identity.oac[0].id
    }
  }

  default_cache_behavior {
    target_origin_id       = "${local.default.name}-origin"
    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id        = aws_cloudfront_cache_policy.cache["${local.default.name}-origin"]
    allowed_methods = [
      "HEAD",
      "DELETE",
      "POST",
      "GET",
      "OPTIONS",
      "PUT",
      "PATCH"
    ]
    cached_methods = [
      "HEAD",
      "DELETE",
      "POST",
      "GET",
      "OPTIONS",
      "PUT",
      "PATCH"
    ]
  }

  dynamic "ordered_cache_behavior" {
    for_each = var.resources
    content {
      cache_policy_id        = "${each.value.name}-cache-policy"
      target_origin_id       = "${each.value.name}-origin"
      path_pattern           = each.value.route
      viewer_protocol_policy = "redirect-to-https"
      allowed_methods = [
        "HEAD",
        "DELETE",
        "POST",
        "GET",
        "OPTIONS",
        "PUT",
        "PATCH"
      ]
      cached_methods = [
        "HEAD",
        "DELETE",
        "POST",
        "GET",
        "OPTIONS",
        "PUT",
        "PATCH"
      ]
    }
  }
  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
