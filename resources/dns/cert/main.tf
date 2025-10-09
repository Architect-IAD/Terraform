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
    for i, dvo in var.domain_validation_options :
    i => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.default.zone_id
  
  name    = each.value.name
  type    = each.value.type
  records = [each.value.value]
  
  ttl     = 60
  allow_overwrite = true
}

output "validation_records" {
  value = [for r in aws_route53_record.cert_validation : r.fqdn]
}


