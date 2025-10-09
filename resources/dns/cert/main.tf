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
    for dvo in var.domain_validation_options :
    "${dvo.resource_record_name}|${dvo.resource_record_type}" => dvo...
  }

  zone_id = data.aws_route53_zone.default.zone_id
  name    = split("|", each.key)[0]
  type    = split("|", each.key)[1]
  ttl     = 60

  # Use the first group's value (they're typically identical)
  records = [each.value[0].resource_record_value]

  allow_overwrite = true
}

output "validation_records" {
  value = [for r in aws_route53_record.cert_validation : r.fqdn]
}
