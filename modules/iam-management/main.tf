# IAM Management Module - Clean Version
# Manages IAM policies, roles, and instance profiles

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

# IAM Policies
resource "aws_iam_policy" "custom" {
  for_each = var.policies
  
  name        = "${var.policy_prefix}${each.key}"
  description = each.value.description
  policy      = each.value.policy_document
  
  tags = merge(
    var.common_tags,
    {
      Name        = "${var.policy_prefix}${each.key}"
      Type        = "CustomPolicy"
      Environment = var.environment
    }
  )
}

# IAM Roles
resource "aws_iam_role" "custom" {
  for_each = var.roles
  
  name                 = "${var.role_prefix}${each.key}"
  description          = each.value.description
  assume_role_policy   = each.value.assume_role_policy
  max_session_duration = each.value.max_session_duration
  
  tags = merge(
    var.common_tags,
    {
      Name        = "${var.role_prefix}${each.key}"
      Type        = "CustomRole"
      Environment = var.environment
    }
  )
}

# Instance profiles for EC2 roles (only created when needed)
resource "aws_iam_instance_profile" "custom" {
  for_each = {
    for name, role in var.roles : name => role 
    if lookup(role, "create_instance_profile", false)
  }
  
  name = "${var.role_prefix}${each.key}-instance-profile"
  role = aws_iam_role.custom[each.key].name
  
  tags = merge(
    var.common_tags,
    {
      Name        = "${var.role_prefix}${each.key}-instance-profile"
      Type        = "InstanceProfile"
      Environment = var.environment
    }
  )
}