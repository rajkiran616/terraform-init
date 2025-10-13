# IAM Management Module
# Comprehensive IAM resource management using for_each pattern
# This design allows for flexible resource creation and easy importing of existing resources

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

# IAM Policies
resource "aws_iam_policy" "this" {
  for_each = var.iam_policies

  name        = lookup(each.value, "name", each.key)
  name_prefix = lookup(each.value, "name_prefix", null)
  description = lookup(each.value, "description", "Policy managed by Terraform")
  path        = lookup(each.value, "path", "/")
  policy      = each.value.policy_document

  tags = merge(
    var.common_tags,
    lookup(each.value, "tags", {}),
    {
      Name = each.key
      Type = "IAMPolicy"
    }
  )
}

# IAM Roles
resource "aws_iam_role" "this" {
  for_each = var.iam_roles

  name                  = lookup(each.value, "name", each.key)
  name_prefix          = lookup(each.value, "name_prefix", null)
  description          = lookup(each.value, "description", "Role managed by Terraform")
  path                 = lookup(each.value, "path", "/")
  assume_role_policy   = each.value.assume_role_policy
  max_session_duration = lookup(each.value, "max_session_duration", 3600)
  permissions_boundary = lookup(each.value, "permissions_boundary", null)
  force_detach_policies = lookup(each.value, "force_detach_policies", false)

  dynamic "inline_policy" {
    for_each = lookup(each.value, "inline_policies", [])
    content {
      name   = inline_policy.value.name
      policy = inline_policy.value.policy
    }
  }

  tags = merge(
    var.common_tags,
    lookup(each.value, "tags", {}),
    {
      Name = each.key
      Type = "IAMRole"
    }
  )
}

# IAM Users
resource "aws_iam_user" "this" {
  for_each = var.iam_users

  name                 = lookup(each.value, "name", each.key)
  path                 = lookup(each.value, "path", "/")
  permissions_boundary = lookup(each.value, "permissions_boundary", null)
  force_destroy       = lookup(each.value, "force_destroy", false)

  tags = merge(
    var.common_tags,
    lookup(each.value, "tags", {}),
    {
      Name = each.key
      Type = "IAMUser"
    }
  )
}

# IAM Groups
resource "aws_iam_group" "this" {
  for_each = var.iam_groups

  name = lookup(each.value, "name", each.key)
  path = lookup(each.value, "path", "/")
}

# IAM Instance Profiles
resource "aws_iam_instance_profile" "this" {
  for_each = var.iam_instance_profiles

  name        = lookup(each.value, "name", each.key)
  name_prefix = lookup(each.value, "name_prefix", null)
  path        = lookup(each.value, "path", "/")
  role        = lookup(each.value, "role_key", null) != null ? aws_iam_role.this[each.value.role_key].name : lookup(each.value, "role_name", null)

  tags = merge(
    var.common_tags,
    lookup(each.value, "tags", {}),
    {
      Name = each.key
      Type = "IAMInstanceProfile"
    }
  )
}

# IAM Policy Attachments - Role
resource "aws_iam_role_policy_attachment" "this" {
  for_each = var.iam_role_policy_attachments

  role       = lookup(each.value, "role_key", null) != null ? aws_iam_role.this[each.value.role_key].name : each.value.role_name
  policy_arn = lookup(each.value, "policy_key", null) != null ? aws_iam_policy.this[each.value.policy_key].arn : each.value.policy_arn
}

# IAM Policy Attachments - User
resource "aws_iam_user_policy_attachment" "this" {
  for_each = var.iam_user_policy_attachments

  user       = lookup(each.value, "user_key", null) != null ? aws_iam_user.this[each.value.user_key].name : each.value.user_name
  policy_arn = lookup(each.value, "policy_key", null) != null ? aws_iam_policy.this[each.value.policy_key].arn : each.value.policy_arn
}

# IAM Policy Attachments - Group
resource "aws_iam_group_policy_attachment" "this" {
  for_each = var.iam_group_policy_attachments

  group      = lookup(each.value, "group_key", null) != null ? aws_iam_group.this[each.value.group_key].name : each.value.group_name
  policy_arn = lookup(each.value, "policy_key", null) != null ? aws_iam_policy.this[each.value.policy_key].arn : each.value.policy_arn
}

# IAM Group Memberships
resource "aws_iam_group_membership" "this" {
  for_each = var.iam_group_memberships

  name  = each.key
  group = lookup(each.value, "group_key", null) != null ? aws_iam_group.this[each.value.group_key].name : each.value.group_name
  users = [
    for user_ref in each.value.users : (
      can(regex("^[a-zA-Z0-9_-]+$", user_ref)) && contains(keys(var.iam_users), user_ref) ?
      aws_iam_user.this[user_ref].name : user_ref
    )
  ]
}

# IAM Access Keys
resource "aws_iam_access_key" "this" {
  for_each = var.iam_access_keys

  user    = lookup(each.value, "user_key", null) != null ? aws_iam_user.this[each.value.user_key].name : each.value.user_name
  status  = lookup(each.value, "status", "Active")
  pgp_key = lookup(each.value, "pgp_key", null)
}

# IAM User Login Profiles (Console Access)
resource "aws_iam_user_login_profile" "this" {
  for_each = var.iam_user_login_profiles

  user                    = lookup(each.value, "user_key", null) != null ? aws_iam_user.this[each.value.user_key].name : each.value.user_name
  pgp_key                = each.value.pgp_key
  password_length        = lookup(each.value, "password_length", 20)
  password_reset_required = lookup(each.value, "password_reset_required", true)
}

# IAM SAML Providers
resource "aws_iam_saml_provider" "this" {
  for_each = var.iam_saml_providers

  name                   = each.key
  saml_metadata_document = each.value.saml_metadata_document

  tags = merge(
    var.common_tags,
    lookup(each.value, "tags", {}),
    {
      Name = each.key
      Type = "IAMSAMLProvider"
    }
  )
}

# IAM OIDC Providers
resource "aws_iam_openid_connect_provider" "this" {
  for_each = var.iam_oidc_providers

  url             = each.value.url
  client_id_list  = each.value.client_id_list
  thumbprint_list = each.value.thumbprint_list

  tags = merge(
    var.common_tags,
    lookup(each.value, "tags", {}),
    {
      Name = each.key
      Type = "IAMOIDCProvider"
    }
  )
}
