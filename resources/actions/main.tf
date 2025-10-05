variable "repo" {
  type = string
}

variable "org" {
  type = string
}

variable "policy" {
  type = object({
    update_action = string
    resource_arn  = string
  })
}

data "aws_iam_openid_connect_provider" "example" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_role" "gh_roles" {
  name = "GitubActions-${var.org}-${var.repo}-Access"
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
            "token.actions.githubusercontent.com:sub" : "repo: <${var.org}/${var.repo}>:*",
            "token.actions.githubusercontent.com:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "gh_actions" {
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          var.policy.update_action
        ],
        "Resource" : [var.policy.resource_arn]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.gh_roles.name
  policy_arn = aws_iam_policy.gh_actions.arn
}

output "role_id" {
  value = aws_iam_role.gh_roles.arn
}

