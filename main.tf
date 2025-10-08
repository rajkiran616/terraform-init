# Main Terraform configuration
# Uses the IAM management module to create policies and roles

# Data sources for account information
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Local values for resource naming and tagging
locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  
  # Environment-specific naming
  name_prefix = var.environment == "production" ? "prod" : var.environment
  
  # Merged tags
  common_tags = merge(
    var.default_tags,
    {
      Environment = var.environment
      Account     = local.account_id
      Region      = local.region
      Workspace   = terraform.workspace
    }
  )
}

# IAM Management Module
module "iam_management" {
  source = "./modules/iam-management"
  
  # Basic configuration
  environment   = var.environment
  account_id    = local.account_id
  region        = local.region
  project_name  = var.project_name
  
  # Naming configuration
  policy_prefix = var.policy_prefix != "" ? var.policy_prefix : "${local.name_prefix}-"
  role_prefix   = var.role_prefix != "" ? var.role_prefix : "${local.name_prefix}-"
  
  # IAM resources
  policies = var.iam_policies
  roles    = var.iam_roles
  
  # Tagging
  common_tags = local.common_tags
}