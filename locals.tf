# Environment-based configuration selection from AWS AppConfig
locals {
  # AppConfig application details
  appconfig_app_name = "terraform-iam-config"
  
  # Select the environment configuration based on the environment variable
  # This dynamically selects the correct data source based on the environment
  environment_config_content = var.environment == "dev" ? (
    length(data.aws_appconfig_configuration.environment_config_dev) > 0 ? data.aws_appconfig_configuration.environment_config_dev[0].content : "{}"
  ) : var.environment == "qa" ? (
    length(data.aws_appconfig_configuration.environment_config_qa) > 0 ? data.aws_appconfig_configuration.environment_config_qa[0].content : "{}"
  ) : (
    length(data.aws_appconfig_configuration.environment_config_prod) > 0 ? data.aws_appconfig_configuration.environment_config_prod[0].content : "{}"
  )
  
  environment_config = jsondecode(local.environment_config_content)
  
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