terraform {
  required_providers { aws = { source = "hashicorp/aws" } }
}

variable "role_name" {
  type = string
}

resource "aws_secretsmanager_secret" "this" {
  name                    = "editor_config"
  description             = "App secret for Lambda"
  recovery_window_in_days = 0
}

data "aws_iam_policy_document" "lambda_read_secret" {
  statement {
    sid    = "ReadSecret"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [
      aws_secretsmanager_secret.this.arn,
      "${aws_secretsmanager_secret.this.arn}*"
    ]
  }

  statement {
    sid     = "KmsDecryptForSecret"
    effect  = "Allow"
    actions = ["kms:Decrypt"]
    resources = [
      aws_secretsmanager_secret.this.arn,
      "${aws_secretsmanager_secret.this.arn}*"
    ]
  }
}

resource "aws_iam_policy" "lambda_read_secret" {
  name   = "LambdaReadSecret-config"
  policy = data.aws_iam_policy_document.lambda_read_secret.json
}


resource "aws_iam_role_policy_attachment" "attach" {
  role       = var.role_name
  policy_arn = aws_iam_policy.lambda_read_secret.arn
}