# Environment-based configuration selection from JSON files
locals {
  # Load JSON configuration files
  dev_config_raw  = jsondecode(file("${path.module}/config/dev.json"))
  qa_config_raw   = jsondecode(file("${path.module}/config/qa.json"))
  prod_config_raw = jsondecode(file("${path.module}/config/prod.json"))
  
  # Select the environment configuration based on the environment variable
  environment_config = var.environment == "dev" ? local.dev_config_raw : (
    var.environment == "qa" ? local.qa_config_raw : (
      var.environment == "prod" ? local.prod_config_raw : null
    )
  )
  
  # Extract configuration values
  account_id         = local.environment_config.account_id
  account_name       = local.environment_config.account_name
  region             = local.environment_config.region
  cross_account_role = local.environment_config.cross_account_role
  
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