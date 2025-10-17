# Environment-based configuration selection
locals {
  # Select the environment configuration based on the environment variable
  environment_config = var.environment == "dev" ? local.dev_config : (
    var.environment == "qa" ? local.qa_config : (
      var.environment == "prod" ? local.prod_config : null
    )
  )
  
  # Extract configuration values
  account_id         = local.environment_config.account_id
  account_name       = local.environment_config.account_name
  region             = local.environment_config.region
  cross_account_role = local.environment_config.cross_account_role
  
  # IAM policies for the selected environment
  iam_policies = local.environment_config.iam_policies
  
  # IAM roles for the selected environment
  iam_roles = local.environment_config.iam_roles
  
  # Create flattened policy structure for resources
  policies_for_deployment = {
    for policy_key, policy_config in local.iam_policies : 
    "${local.account_id}_${var.environment}_${policy_key}" => {
      key            = "${local.account_id}_${var.environment}_${policy_key}"
      account_id     = local.account_id
      account_name   = local.account_name
      environment    = var.environment
      policy_key     = policy_key
      policy_config  = policy_config
    }
  }
  
  # Create flattened role structure for resources
  roles_for_deployment = {
    for role_key, role_config in local.iam_roles : 
    "${local.account_id}_${var.environment}_${role_key}" => {
      key           = "${local.account_id}_${var.environment}_${role_key}"
      account_id    = local.account_id
      account_name  = local.account_name
      environment   = var.environment
      role_key      = role_key
      role_config   = role_config
    }
  }
}

# Debug outputs (comment these out in production)
# output "debug_target_account_config" {
#   value = local.target_account_config
# }
# 
# output "debug_target_environment_config" {
#   value = local.target_environment_config
# }
# 
# output "debug_iam_policies" {
#   value = local.iam_policies
# }