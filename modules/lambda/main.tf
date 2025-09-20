locals {
  function_name = "${var.settings}-${vars.lambda_name}"
}

resource "aws_iam_role" "role" {
  provider = aws.configuration
  name = "${local.function_name}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_lambda_function" "lambda" {

  function_name = local.function_name
  role          = aws_iam_role.role.lambda_exec.arn
}

