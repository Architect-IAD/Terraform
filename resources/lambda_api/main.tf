terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

variable "name" {
  type = string
}

variable "git" {
  type = object({
    repo = string
    org  = string
  })
}

variable "config" {
  type = object({
    memory = optional(number)
  })
  default = {
    memory = 512
  }
  nullable = true
}

locals {
  prefix = "Lambda-${var.name}"
}

resource "aws_iam_role" "lambda_role" {
  name = "${local.prefix}-Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "default" {
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.lambda_role.id
  policy_arn = aws_iam_policy.default.arn
}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/build" # zips the contents, not the folder
  output_path = "${path.module}/build.zip"
}

resource "aws_lambda_function" "default" {
  function_name = var.name
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  memory_size   = var.config.memory

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash,
    ]
  }
}

module "action" {
  source = "../actions"
  repo   = var.git.repo
  org    = var.git.org
  policy = {
    resource_arn  = aws_lambda_function.default.arn
    update_action = "lambda:UpdateFunctionCode"
  }
}

resource "aws_lambda_function_url" "public" {
  function_name      = aws_lambda_function.default.function_name
  authorization_type = "NONE"
}

resource "aws_lambda_permission" "public_url_invoke" {
  statement_id           = "AllowPublicFunctionUrlInvoke"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.default.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

output "role" {
  value = aws_iam_role.lambda_role.name
}

output "url" {
  value = aws_lambda_function_url.public.function_url
}

output "cf_config" {
  value = {
    domain = aws_lambda_function_url.public.function_url
    name   = var.name
  }

}