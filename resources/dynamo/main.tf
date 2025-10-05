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

variable "accessors" {
  type = list(object({
    role_name = string
    actions   = list(string)
  }))
}

variable "keys" {
  type = object({
    primary = object({
      name = string
      type = string
    })
    secondary = optional(object({
      name = string
      type = string
    }))
    ttl = optional(string)
  })
}

locals {
  prefix = "Dynamo-${var.name}"
}

resource "aws_dynamodb_table" "database" {
  name         = var.name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = var.keys.primary.name

  dynamic "attribute" {
    for_each = [ for k in [var.keys.primary, var.keys.secondary] : k if k != null ]

    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  dynamic "global_secondary_index" {
    iterator = gsi
    for_each = var.keys.secondary != null ? [var.keys.secondary] : []

    content {
      name            = "GSI-${gsi.value.name}"
      hash_key        = gsi.value.name
      projection_type = "ALL"
    }
  }

  dynamic "ttl" {
    iterator = ttl_attr
    for_each = var.keys.ttl != null ? [var.keys.ttl] : []

    content {
      attribute_name = ttl_attr.value
      enabled        = true
    }
  }

  server_side_encryption { enabled = true }
  point_in_time_recovery { enabled = true }
}

resource "aws_iam_policy" "accessors" {
  for_each = { for i, v in var.accessors : i => v }
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : each.value.actions,
        "Resource" : [
          aws_dynamodb_table.database.arn,
          "${aws_dynamodb_table.database.arn}/index/*"
        ]
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach" {
  for_each   = { for i, v in var.accessors : i => v }
  role       = each.value.role_name
  policy_arn = aws_iam_policy.accessors[each.key].arn
}


output "arn" {
  value = aws_dynamodb_table.database.arn
}