# IAM module for cross-account access and resource management

# Cross-account access role for Terraform
resource "aws_iam_role" "terraform_cross_account_role" {
  count = var.create_cross_account_role ? 1 : 0
  
  name = var.cross_account_role_name
  path = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = var.trusted_account_arns
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.external_id
          }
        }
      }
    ]
  })

  tags = var.tags
}

# Attach policies to the cross-account role
resource "aws_iam_role_policy_attachment" "terraform_cross_account_policies" {
  count = var.create_cross_account_role ? length(var.policy_arns) : 0
  
  role       = aws_iam_role.terraform_cross_account_role[0].name
  policy_arn = var.policy_arns[count.index]
}

# Custom policy for specific permissions
resource "aws_iam_policy" "terraform_custom_policy" {
  count = var.create_custom_policy && var.custom_policy_document != null ? 1 : 0
  
  name        = var.custom_policy_name
  description = var.custom_policy_description
  policy      = var.custom_policy_document

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "terraform_custom_policy_attachment" {
  count = var.create_custom_policy && var.custom_policy_document != null ? 1 : 0
  
  role       = aws_iam_role.terraform_cross_account_role[0].name
  policy_arn = aws_iam_policy.terraform_custom_policy[0].arn
}

# IAM group for users
resource "aws_iam_group" "infrastructure_group" {
  count = var.create_infrastructure_group ? 1 : 0
  
  name = var.infrastructure_group_name
  path = "/"
}

# IAM group policy attachment
resource "aws_iam_group_policy_attachment" "infrastructure_group_policies" {
  count = var.create_infrastructure_group ? length(var.group_policy_arns) : 0
  
  group      = aws_iam_group.infrastructure_group[0].name
  policy_arn = var.group_policy_arns[count.index]
}

# IAM users
resource "aws_iam_user" "infrastructure_users" {
  for_each = var.infrastructure_users
  
  name = each.key
  path = "/"
  
  tags = merge(var.tags, {
    Role = each.value.role
  })
}

# Add users to group
resource "aws_iam_user_group_membership" "infrastructure_users_membership" {
  for_each = var.create_infrastructure_group && length(var.infrastructure_users) > 0 ? var.infrastructure_users : {}
  
  user   = aws_iam_user.infrastructure_users[each.key].name
  groups = [aws_iam_group.infrastructure_group[0].name]
}

# Standard IAM roles (no service-linked roles)
resource "aws_iam_role" "standard_roles" {
  for_each = var.standard_roles
  
  name                 = each.key
  path                 = "/"
  description          = each.value.description
  max_session_duration = lookup(each.value, "max_session_duration", 3600)

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = each.value.trusted_entities
        }
        Condition = lookup(each.value, "conditions", {})
      }
    ]
  })

  tags = merge(var.tags, lookup(each.value, "tags", {}))
}

# Attach managed policies to standard roles
resource "aws_iam_role_policy_attachment" "standard_role_managed_policies" {
  for_each = {
    for combo in flatten([
      for role_key, role in var.standard_roles : [
        for policy_arn in role.managed_policy_arns : {
          role_key   = role_key
          policy_arn = policy_arn
          key        = "${role_key}-${replace(policy_arn, "/[^a-zA-Z0-9]/", "-")}"
        }
      ]
    ]) : combo.key => combo
  }
  
  role       = aws_iam_role.standard_roles[each.value.role_key].name
  policy_arn = each.value.policy_arn
}

# Attach inline policies to standard roles
resource "aws_iam_role_policy" "standard_role_inline_policies" {
  for_each = {
    for combo in flatten([
      for role_key, role in var.standard_roles : [
        for policy_name, policy_doc in lookup(role, "inline_policies", {}) : {
          role_key    = role_key
          policy_name = policy_name
          policy_doc  = policy_doc
          key         = "${role_key}-${policy_name}"
        }
      ]
    ]) : combo.key => combo
  }
  
  name   = each.value.policy_name
  role   = aws_iam_role.standard_roles[each.value.role_key].id
  policy = each.value.policy_doc
}

# Instance profiles for EC2 roles
resource "aws_iam_instance_profile" "standard_instance_profiles" {
  for_each = {
    for key, role in var.standard_roles : key => role
    if contains(role.trusted_entities, "ec2.amazonaws.com")
  }
  
  name = "${each.key}-instance-profile"
  role = aws_iam_role.standard_roles[each.key].name

  tags = var.tags
}
