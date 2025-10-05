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

variable "cf" {
  type = object({
    name    = string
    zone_id = string
    domain  = string
  })
}

data "aws_route53_zone" "default" {
  name         = var.domain
  private_zone = false
}

resource "aws_route53_record" "domain" {
  zone_id = data.aws_route53_zone.default.zone_id
  name    = var.cf.domain
  type    = "A"

  alias {
    name                   = var.cf.name
    zone_id                = var.cf.zone_id
    evaluate_target_health = false
  }
}
