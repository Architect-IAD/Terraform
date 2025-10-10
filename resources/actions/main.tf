terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

variable "git" {
  type = object({
    repo = string
    org  = string
  })
}

data "aws_iam_openid_connect_provider" "example" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_role" "gh_role" {
  name = "GitubActions-${var.git.org}-${var.git.repo}-Access"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : "${data.aws_iam_openid_connect_provider.example.arn}"
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringEquals" : {
            "token.actions.githubusercontent.com:aud" : "sts.amazonaws.com"
          },
          "StringLike": {
            "token.actions.githubusercontent.com:sub" : "repo:${var.git.org}/${var.git.repo}:*",
          }
        }
      }
    ]
  })
}

output "role_name" {
  value = aws_iam_role.gh_role.name
}

