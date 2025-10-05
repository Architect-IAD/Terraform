terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

variable "dynamo_arn" {
  type = string
}

resource "aws_iam_user" "firebase" {
  name = "firebase"
}

resource "aws_iam_access_key" "key" {
  user = aws_iam_user.firebase.name
}

resource "null_resource" "print_keys_windows" {
  triggers = { key_id = aws_iam_access_key.key.id }

  provisioner "local-exec" {
    when    = create
    command = "echo \"AccessKeyId: $ACCESS_KEY_ID\"; echo \"SecretAccessKey: $SECRET_ACCESS_KEY\""
    environment = {
      ACCESS_KEY_ID     = aws_iam_access_key.key.id
      SECRET_ACCESS_KEY = nonsensitive(aws_iam_access_key.key.secret)
    }
  }
}

resource "aws_iam_user_policy" "user_policies" {
  name = "Firebase-Policy"
  user = aws_iam_user.firebase.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : ["dynamodb:PutItem"],
        "Resource" : [
          var.dynamo_arn,
          "${var.dynamo_arn}/index/*"
        ]
      },
    ]
  })
}