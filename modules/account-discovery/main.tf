# Account Discovery Module
# Dynamically discovers accounts from AWS Organizations and creates account-specific resources

# Data source to get organization information
data "aws_organizations_organization" "current" {}

# Data source to get all accounts in the organization
data "aws_organizations_accounts" "all" {}

# Filter accounts based on tags or naming patterns
locals {
  # All accounts in the organization
  all_accounts = {
    for account in data.aws_organizations_accounts.all.accounts : account.id => {
      id     = account.id
      name   = account.name
      email  = account.email
      status = account.status
      arn    = account.arn
      tags   = lookup(account, "tags", {})
    }
  }

  # Filter active accounts only
  active_accounts = {
    for id, account in local.all_accounts : id => account
    if account.status == "ACTIVE"
  }

  # Categorize accounts based on naming convention or tags
  # Assumes account names follow pattern: "company-environment-purpose" or have Environment tag
  account_environments = {
    for id, account in local.active_accounts : id => {
      id          = account.id
      name        = account.name
      email       = account.email
      environment = try(
        # First try to get environment from tags
        lower(account.tags["Environment"]),
        # Then try to extract from account name (assuming pattern: prefix-environment-suffix)
        length(split("-", account.name)) >= 2 ? lower(split("-", account.name)[1]) : "unknown"
      )
      purpose = try(
        # Try to get purpose/role from tags
        lower(account.tags["Purpose"]),
        # Then try to extract from account name
        length(split("-", account.name)) >= 3 ? lower(split("-", account.name)[2]) : "workload"
      )
      account_type = try(
        lower(account.tags["AccountType"]),
        # Determine account type based on environment
        contains(["prod", "production"], lower(account.name)) ? "production" :
        contains(["dev", "development"], lower(account.name)) ? "development" :
        contains(["staging", "stage"], lower(account.name)) ? "staging" :
        contains(["shared", "core", "security"], lower(account.name)) ? "shared" :
        account.id == data.aws_organizations_organization.current.master_account_id ? "master" : "workload"
      )
    }
  }

  # Group accounts by environment
  accounts_by_environment = {
    for env in distinct([for acc in local.account_environments : acc.environment]) : env => {
      for id, acc in local.account_environments : id => acc
      if acc.environment == env
    }
  }

  # Group accounts by type
  accounts_by_type = {
    for type in distinct([for acc in local.account_environments : acc.account_type]) : type => {
      for id, acc in local.account_environments : id => acc
      if acc.account_type == type
    }
  }

  # Master/Root account
  master_account = {
    for id, acc in local.account_environments : id => acc
    if id == data.aws_organizations_organization.current.master_account_id
  }

  # Workload accounts (excludes master and shared service accounts)
  workload_accounts = {
    for id, acc in local.account_environments : id => acc
    if !contains(["master", "shared", "security", "logging"], acc.account_type)
  }

  # Generate cross-account role ARNs for each account
  cross_account_role_arns = {
    for id, acc in local.active_accounts : id => "arn:aws:iam::${id}:role/${var.cross_account_role_name}"
  }

  # Generate backend configurations for each environment
  backend_configs = {
    for env, accounts in local.accounts_by_environment : env => {
      accounts = accounts
      backend_config = {
        bucket         = var.terraform_state_bucket
        key           = "${env}/terraform.tfstate"
        region        = var.aws_region
        dynamodb_table = var.terraform_lock_table
        encrypt       = true
      }
    }
  }
}

# Output account discovery results
output "all_accounts" {
  description = "All accounts in the organization"
  value       = local.all_accounts
}

output "active_accounts" {
  description = "All active accounts in the organization"
  value       = local.active_accounts
}

output "account_environments" {
  description = "Accounts categorized by environment and type"
  value       = local.account_environments
}

output "accounts_by_environment" {
  description = "Accounts grouped by environment"
  value       = local.accounts_by_environment
}

output "accounts_by_type" {
  description = "Accounts grouped by account type"
  value       = local.accounts_by_type
}

output "master_account" {
  description = "Master/Root account information"
  value       = local.master_account
}

output "workload_accounts" {
  description = "Workload accounts (excludes master and shared services)"
  value       = local.workload_accounts
}

output "cross_account_role_arns" {
  description = "Cross-account role ARNs for all accounts"
  value       = local.cross_account_role_arns
}

output "backend_configs" {
  description = "Backend configurations for each environment"
  value       = local.backend_configs
}

# Create cross-account roles in each account (when run in master account)
module "cross_account_roles" {
  source = "../iam"
  
  for_each = var.create_cross_account_roles ? local.active_accounts : {}
  
  providers = {
    aws = aws.target_account
  }
  
  create_cross_account_role = true
  cross_account_role_name   = var.cross_account_role_name
  trusted_account_arns = [
    data.aws_organizations_organization.current.master_account_arn,
    # Allow other accounts to assume roles in this account if needed
    "arn:aws:iam::${data.aws_organizations_organization.current.master_account_id}:root"
  ]
  external_id = var.cross_account_external_id
  
  policy_arns = var.cross_account_policy_arns
  
  tags = merge(var.default_tags, {
    AccountId   = each.key
    AccountName = each.value.name
    ManagedBy   = "Terraform"
  })
}

# Create account-specific provider aliases dynamically
# Note: This would need to be used with generated provider configurations
locals {
  provider_configurations = {
    for id, acc in local.active_accounts : replace(acc.name, "-", "_") => {
      account_id = id
      role_arn   = "arn:aws:iam::${id}:role/${var.cross_account_role_name}"
      alias      = replace(lower(acc.name), "-", "_")
    }
  }
}