variable "region" {
  type = string
}

variable "environment" {
  type = string
}

variable "project_name" {
  type = string
}

output "settings" {
  value = {
    project_name = var.project_name
    region       = var.region
    environment  = var.environment
    prefix       = "${var.project_name}-${var.environment}-${var.region}"
  }
}
