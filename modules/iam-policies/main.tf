# IAM Policies Module
# This module creates and manages IAM policies and roles across accounts

# Create IAM policy from JSON document
resource "aws_iam_policy" "custom_policy" {
  for_each = var.policies

  name        = each.key
  path        = var.policy_path
  description = each.value.description

  policy = jsonencode(each.value.policy_document)

  tags = merge(
    var.common_tags,
    {
      Name = each.key
      Type = "CustomPolicy"
    }
  )
}

# Create IAM roles if specified
resource "aws_iam_role" "custom_role" {
  for_each = var.roles

  name               = each.key
  path               = var.role_path
  assume_role_policy = jsonencode(each.value.assume_role_policy)
  description        = each.value.description
  max_session_duration = each.value.max_session_duration

  tags = merge(
    var.common_tags,
    {
      Name = each.key
      Type = "CustomRole"
    }
  )
}

# Attach policies to roles
resource "aws_iam_role_policy_attachment" "role_policy_attachment" {
  for_each = local.role_policy_attachments

  role       = aws_iam_role.custom_role[each.value.role].name
  policy_arn = each.value.policy_type == "custom" ? aws_iam_policy.custom_policy[each.value.policy].arn : each.value.policy
}

# Create instance profiles for EC2 roles if needed
resource "aws_iam_instance_profile" "instance_profile" {
  for_each = { for k, v in var.roles : k => v if v.create_instance_profile }

  name = each.key
  role = aws_iam_role.custom_role[each.key].name

  tags = merge(
    var.common_tags,
    {
      Name = "${each.key}-instance-profile"
      Type = "InstanceProfile"
    }
  )
}

# Local values for processing role-policy attachments
locals {
  role_policy_attachments = merge([
    for role_name, role_config in var.roles : {
      for policy in role_config.attached_policies : "${role_name}-${policy}" => {
        role = role_name
        policy = policy
        policy_type = contains(keys(var.policies), policy) ? "custom" : "aws_managed"
      }
    }
  ]...)
}