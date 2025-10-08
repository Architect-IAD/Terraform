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

resource "aws_acm_certificate" "default" {
  domain_name       = "${var.domain}"
  subject_alternative_names = ["*.${var.domain}"]
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

output "arn" {
  value = aws_acm_certificate.default.arn
}

output "domain_validation_options" {
  value = aws_acm_certificate.default.domain_validation_options
}