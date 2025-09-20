
locals {
  project_name = "testing"
  
}

component "globals" {
  source = "modules/globals"

  inputs = {
    region = var.region
    environment = var.environment
    project_name = local.project_name
  }
}

component "api" {
  source = "modules/lambda"
  inputs = {
    function_name = "api"
    settings = component.globals.settings
  }
  providers = component.globals.providers
}

component "static" {
  source = "modules/s3"
  inputs = {
    bucket_name = "static"
    settings = component.globals.settings
  }
  providers = component.globals.providers
}

component "cdn" {
  source = "modules/cloudfront"
  inputs = {
    bucket_name = "static"
    settings = component.globals.settings
  }
  providers = component.globals.providers
}

