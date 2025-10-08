# Simplified IAM Management Module
# This version avoids complex for expressions entirely

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

# IAM Policies - Simple approach
resource "aws_iam_policy" "policies" {
  for_each = var.policies
  
  name        = "${var.policy_prefix}${each.key}"
  description = each.value.description
  policy      = each.value.policy_document
  
  tags = merge(var.common_tags, {
    Name = "${var.policy_prefix}${each.key}"
    Type = "CustomPolicy"
  })
}

# IAM Roles - Simple approach
resource "aws_iam_role" "roles" {
  for_each = var.roles
  
  name                 = "${var.role_prefix}${each.key}"
  description          = each.value.description
  assume_role_policy   = each.value.assume_role_policy
  max_session_duration = each.value.max_session_duration
  
  tags = merge(var.common_tags, {
    Name = "${var.role_prefix}${each.key}"
    Type = "CustomRole"
  })
}

# Note: Policy attachments would need to be handled separately
# This avoids the complex for expressions but requires more manual work