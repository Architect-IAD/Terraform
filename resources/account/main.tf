terraform {
  required_providers {
    architect = {
      source = "registry.terraform.io/Architect-IAD/arc"
    }
  }
}

resource "aws_organizations_organizational_unit" "closed_ou" {
  parent_id = var.org_id
  name      = "closed_accounts"
}

resource "architect_aws_account" "default" {
  name           = var.name
  email          = var.email
  closed_unit_id = data.aws_organizations_organizational_unit.closed_ou.id
  unit_id        = var.organizational_unit_id
}

output "id" {
  value = architect_aws_account.default.account_id
}

output "account_id" {
  value = architect_aws_account.default.account_id
}