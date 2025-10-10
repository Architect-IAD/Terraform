terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

locals {
  prefix = "CloudFront-${var.cdn_name}"
  default_functions = [for i, r in var.functions : {
    i    = i
    type = "function"
    r    = r
  } if r.default]
  default_buckets = [for i, r in var.buckets : {
    i    = i
    type = "s3"
    r    = r
  } if r.default]
  default = length(local.default_functions) > 0 ? local.default_functions[0] : local.default_buckets[0]
}

resource "aws_cloudfront_cache_policy" "cache" {
  for_each = { for i, r in var.buckets : i => r }
  name     = "${local.prefix}-cache-policy-${each.value.name}"

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

resource "aws_cloudfront_cache_policy" "no_cache" {
  for_each    = { for i, r in var.functions : i => r }
  name        = "${local.prefix}-no-cache"
  min_ttl     = 0
  default_ttl = 1
  max_ttl     = 1

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_gzip = true
    cookies_config { cookie_behavior = "all" }
    headers_config { header_behavior = "none" }
    query_strings_config { query_string_behavior = "all" }
  }
}

resource "aws_cloudfront_distribution" "cdn" {
  enabled = true
  comment = local.prefix

  dynamic "origin" {
    for_each = var.buckets
    content {
      origin_id   = origin.value.name
      domain_name = origin.value.domain

      s3_origin_config {
        origin_access_identity = "origin-access-identity/cloudfront/${origin.value.oai_id}"
      }
    }
  }

  dynamic "origin" {
    for_each = var.functions
    content {
      origin_id   = origin.value.name
      domain_name = replace(replace(origin.value.domain, "https://", ""), "/", "")

      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  default_cache_behavior {
    target_origin_id       = local.default.r.name
    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id        = local.default.type == "s3" ? aws_cloudfront_cache_policy.cache[local.default.i].id : aws_cloudfront_cache_policy.no_cache[local.default.i].id
    allowed_methods = [
      "HEAD",
      "DELETE",
      "POST",
      "GET",
      "OPTIONS",
      "PUT",
      "PATCH"
    ]
    cached_methods = ["GET", "HEAD"]
  }

  dynamic "ordered_cache_behavior" {
    for_each = { for i, r in var.buckets : i => r if local.default.type == "s3" ? i != local.default.i : true }

    content {
      cache_policy_id        = aws_cloudfront_cache_policy.cache[ordered_cache_behavior.key].id
      target_origin_id       = ordered_cache_behavior.value.name
      path_pattern           = ordered_cache_behavior.value.route
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
      cached_methods = ["GET", "HEAD"]
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = { for i, r in var.functions : i => r if local.default.type == "function" ? i != local.default.i : true }

    content {
      cache_policy_id        = aws_cloudfront_cache_policy.no_cache[ordered_cache_behavior.key].id
      target_origin_id       = ordered_cache_behavior.value.name
      path_pattern           = ordered_cache_behavior.value.route
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
      cached_methods = ["GET", "HEAD"]
    }
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    acm_certificate_arn      = var.cert_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  aliases = [var.domain]
}

output "dns" {
  value = {
    name    = aws_cloudfront_distribution.cdn.domain_name
    zone_id = aws_cloudfront_distribution.cdn.hosted_zone_id
    domain  = var.domain
  }
}