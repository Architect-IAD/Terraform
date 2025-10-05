terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

variable "validation_records" {
  type = any
}

variable "cert_arn" {
  type = string
}

resource "aws_acm_certificate_validation" "cert_validating" {
  certificate_arn         = var.cert_arn
  validation_record_fqdns = var.validation_records
}