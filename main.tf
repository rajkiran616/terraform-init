# Data sources for account information (optional)
# Uncomment if you need organization-level information
# data "aws_organizations_organization" "this" {}
# data "aws_organizations_accounts" "this" {}

# Create IAM resources for development environment
module "iam_dev" {
  count = var.environment == "dev" ? 1 : 0
  
  source = "./modules/iam"
  
  providers = {
    aws = aws.dev
  }
  
  environment   = local.environment_config.environment
  account_id    = local.environment_config.account_id
  account_name  = local.environment_config.account_name
  iam_policies  = local.environment_config.iam_policies
  iam_roles     = local.environment_config.iam_roles
}

# Create IAM resources for QA environment
module "iam_qa" {
  count = var.environment == "qa" ? 1 : 0
  
  source = "./modules/iam"
  
  providers = {
    aws = aws.qa
  }
  
  environment   = local.environment_config.environment
  account_id    = local.environment_config.account_id
  account_name  = local.environment_config.account_name
  iam_policies  = local.environment_config.iam_policies
  iam_roles     = local.environment_config.iam_roles
}

# Create IAM resources for production environment
module "iam_prod" {
  count = var.environment == "prod" ? 1 : 0
  
  source = "./modules/iam"
  
  providers = {
    aws = aws.prod
  }
  
  environment   = local.environment_config.environment
  account_id    = local.environment_config.account_id
  account_name  = local.environment_config.account_name
  iam_policies  = local.environment_config.iam_policies
  iam_roles     = local.environment_config.iam_roles
}
