provider "aws" "configuration" {
  config = {
    region = var.region
  }
}