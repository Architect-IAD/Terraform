locals {
  dynamo_name = "${var.settings}-${vars.lambda_name}"
}

resource "aws_dynamodb_table" "dynamo" {
  name           = local.dynamo_name
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }
}