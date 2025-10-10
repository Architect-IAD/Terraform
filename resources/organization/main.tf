terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

data "aws_ssoadmin_instances" "idc" {}

data "aws_organizations_organization" "org" {}

module "mail_accounts" {
  source        = "../mailbox"
  domain        = var.domain
  account_names = concat([var.production_name], var.non_prod_environments)
}

locals {
  instance_id      = tolist(data.aws_ssoadmin_instances.idc.identity_store_ids)[0]
  instance_arn     = tolist(data.aws_ssoadmin_instances.idc.arns)[0]
  production_email = module.mail_accounts.emails[0]
  non_prod_environments = { for i, v in slice((module.mail_accounts.emails), 1, length((module.mail_accounts.emails))) : i => {
    email = v
    name  = var.non_prod_environments[i]
  } }
  org_id = data.aws_organizations_organization.org.roots[0].id
}

check "org_exits" {
  assert {
    condition     = local.org_id != null
    error_message = "Org ID is null"
  }
}

#------------------------------------------------------------ Environment Configuration ------------------------------------------------------------

#------------------------------ Units ------------------------------
resource "aws_organizations_organizational_unit" "production" {
  name      = "production"
  parent_id = local.org_id
}

resource "aws_organizations_organizational_unit" "non_production" {
  count     = length(local.non_prod_environments) > 0 ? 1 : 0
  name      = "non_production"
  parent_id = local.org_id
}

# ------------------------------ Accounts (Environments) ------------------------------

module "production_account" {
  source                 = "../account"
  name                   = var.production_name
  email                  = local.production_email
  organizational_unit_id = aws_organizations_organizational_unit.production.id
  org_id                 = local.org_id
}

module "non_production_accounts" {
  source                 = "../account"
  for_each               = local.non_prod_environments
  name                   = each.value.name
  email                  = each.value.email
  organizational_unit_id = aws_organizations_organizational_unit.non_production[0].id
  org_id                 = local.org_id
}


#------------------------------------------------------------ User Configuration ------------------------------------------------------------
# ------------------------------ Groups ------------------------------
resource "aws_identitystore_group" "devs" {
  identity_store_id = local.instance_id
  display_name      = "devs"
}

resource "aws_identitystore_group" "qas" {
  identity_store_id = local.instance_id
  display_name      = "qas"
}

# ------------------------------ Permission Sets for Groups ------------------------------
resource "aws_ssoadmin_permission_set" "read_write" {
  name             = "ReadWrite"
  instance_arn     = local.instance_arn
  session_duration = "PT4H"
}

resource "aws_ssoadmin_managed_policy_attachment" "read_write_attachment" {
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.read_write.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_ssoadmin_permission_set" "read" {
  name             = "ReadOnly"
  instance_arn     = local.instance_arn
  session_duration = "PT4H"
}

#------------------------------------------ DELETE THIS ------------------------------------------
resource "aws_ssoadmin_managed_policy_attachment" "read_full_Access" {
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.read.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
#-------------------------------------------------------------------------------------------------

resource "aws_ssoadmin_managed_policy_attachment" "readonly" {
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.read.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_ssoadmin_managed_policy_attachment" "readonly_logs" {
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.read.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
}

resource "aws_ssoadmin_managed_policy_attachment" "readonly_iam" {
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.read.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/IAMReadOnlyAccess"
}

resource "aws_ssoadmin_managed_policy_attachment" "readonly_security_audit" {
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.read.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}


# ------------------------------ Attach account (environment) to group with permissions ------------------------------
resource "aws_ssoadmin_account_assignment" "devs_non_prod_rw" {
  for_each           = local.non_prod_environments
  instance_arn       = local.instance_arn
  principal_type     = "GROUP"
  principal_id       = aws_identitystore_group.devs.group_id
  target_type        = "AWS_ACCOUNT"
  target_id          = module.non_production_accounts[each.key].id
  permission_set_arn = aws_ssoadmin_permission_set.read_write.arn
}

resource "aws_ssoadmin_account_assignment" "devs_prod_ro" {
  instance_arn   = local.instance_arn
  principal_type = "GROUP"
  principal_id   = aws_identitystore_group.devs.group_id
  target_type    = "AWS_ACCOUNT"
  target_id      = module.production_account.id

  permission_set_arn = aws_ssoadmin_permission_set.read.arn
}

resource "aws_ssoadmin_account_assignment" "qas_non_prod_ro" {
  for_each       = local.non_prod_environments
  instance_arn   = local.instance_arn
  principal_type = "GROUP"
  principal_id   = aws_identitystore_group.qas.group_id
  target_type    = "AWS_ACCOUNT"
  target_id      = module.non_production_accounts[each.key].id

  permission_set_arn = aws_ssoadmin_permission_set.read.arn
}


# ------------------------------ Users ------------------------------
resource "aws_identitystore_user" "users" {
  for_each          = { for i, x in var.users : i => x }
  identity_store_id = local.instance_id
  user_name         = "${each.value.f_name}_${each.value.l_name}"
  display_name      = "${each.value.f_name}_${each.value.l_name}"

  name {
    given_name  = each.value.f_name
    family_name = each.value.l_name
  }

  emails {
    value   = each.value.email
    primary = true
    type    = "work"
  }
}

resource "aws_identitystore_group_membership" "devs_members" {
  for_each          = { for k, u in var.users : k => u if u.type == "dev" }
  identity_store_id = local.instance_id
  group_id          = aws_identitystore_group.devs.group_id
  member_id         = aws_identitystore_user.users[each.key].user_id
}

resource "aws_identitystore_group_membership" "qas_members" {
  for_each          = { for k, u in var.users : k => u if u.type == "qa" }
  identity_store_id = local.instance_id
  group_id          = aws_identitystore_group.qas.group_id
  member_id         = aws_identitystore_user.users[each.key].user_id
}


output "accounts" {
  value = merge({
    production = {
      account_id = module.production_account.account_id
      name       = var.production_name
    },
    },
    { for i, v in module.non_production_accounts : v.name => {
      account_id = v.account_id
      name       = v.name
  } })
}

