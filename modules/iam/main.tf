# IAM Module - Creates policies and roles for a specific environment
# This module is environment-agnostic and uses the passed provider

# Create IAM policies
resource "aws_iam_policy" "policies" {
  for_each = var.iam_policies
  
  name        = each.value.name
  description = each.value.description
  policy      = each.value.document

  tags = merge(
    {
      ManagedBy   = "terraform"
      Account     = var.account_name
      AccountId   = var.account_id
      Environment = var.environment
      PolicyKey   = each.key
    },
    each.value.tags
  )
}

# Create IAM roles
resource "aws_iam_role" "roles" {
  for_each = var.iam_roles
  
  name               = each.value.name
  description        = each.value.description
  assume_role_policy = each.value.assume_role_policy

  tags = merge(
    {
      ManagedBy   = "terraform"
      Account     = var.account_name
      AccountId   = var.account_id
      Environment = var.environment
      RoleKey     = each.key
    },
    each.value.tags
  )
}