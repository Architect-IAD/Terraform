terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

variable "domain" {
  type = string
}

data "aws_route53_zone" "default" {
  name         = var.domain
  private_zone = false
}

variable "domain_validation_options" {
  type = any
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in var.domain_validation_options : dvo.domain_name => {
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
  zone_id         = data.aws_route53_zone.default.zone_id
}


output "validation_records" {
  value = [for r in aws_route53_record.cert_validation : r.fqdn]
}
