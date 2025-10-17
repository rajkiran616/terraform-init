# Data sources for AWS AppConfig configuration retrieval
# Using environment-specific providers based on the environment variable

# Development AppConfig Data Sources
data "aws_appconfig_application" "iam_config_dev" {
  count    = var.environment == "dev" ? 1 : 0
  provider = aws.dev
  name     = local.appconfig_app_name
}

data "aws_appconfig_environment" "target_environment_dev" {
  count          = var.environment == "dev" ? 1 : 0
  provider       = aws.dev
  application_id = data.aws_appconfig_application.iam_config_dev[0].id
  name          = var.environment
}

data "aws_appconfig_configuration_profile" "environment_profile_dev" {
  count          = var.environment == "dev" ? 1 : 0
  provider       = aws.dev
  application_id = data.aws_appconfig_application.iam_config_dev[0].id
  name          = "${var.environment}-config"
}

data "aws_appconfig_configuration" "environment_config_dev" {
  count                   = var.environment == "dev" ? 1 : 0
  provider                = aws.dev
  application_id          = data.aws_appconfig_application.iam_config_dev[0].id
  environment_id          = data.aws_appconfig_environment.target_environment_dev[0].environment_id
  configuration_profile_id = data.aws_appconfig_configuration_profile.environment_profile_dev[0].configuration_profile_id
}

# QA AppConfig Data Sources
data "aws_appconfig_application" "iam_config_qa" {
  count    = var.environment == "qa" ? 1 : 0
  provider = aws.qa
  name     = local.appconfig_app_name
}

data "aws_appconfig_environment" "target_environment_qa" {
  count          = var.environment == "qa" ? 1 : 0
  provider       = aws.qa
  application_id = data.aws_appconfig_application.iam_config_qa[0].id
  name          = var.environment
}

data "aws_appconfig_configuration_profile" "environment_profile_qa" {
  count          = var.environment == "qa" ? 1 : 0
  provider       = aws.qa
  application_id = data.aws_appconfig_application.iam_config_qa[0].id
  name          = "${var.environment}-config"
}

data "aws_appconfig_configuration" "environment_config_qa" {
  count                   = var.environment == "qa" ? 1 : 0
  provider                = aws.qa
  application_id          = data.aws_appconfig_application.iam_config_qa[0].id
  environment_id          = data.aws_appconfig_environment.target_environment_qa[0].environment_id
  configuration_profile_id = data.aws_appconfig_configuration_profile.environment_profile_qa[0].configuration_profile_id
}

# Production AppConfig Data Sources
data "aws_appconfig_application" "iam_config_prod" {
  count    = var.environment == "prod" ? 1 : 0
  provider = aws.prod
  name     = local.appconfig_app_name
}

data "aws_appconfig_environment" "target_environment_prod" {
  count          = var.environment == "prod" ? 1 : 0
  provider       = aws.prod
  application_id = data.aws_appconfig_application.iam_config_prod[0].id
  name          = var.environment
}

data "aws_appconfig_configuration_profile" "environment_profile_prod" {
  count          = var.environment == "prod" ? 1 : 0
  provider       = aws.prod
  application_id = data.aws_appconfig_application.iam_config_prod[0].id
  name          = "${var.environment}-config"
}

data "aws_appconfig_configuration" "environment_config_prod" {
  count                   = var.environment == "prod" ? 1 : 0
  provider                = aws.prod
  application_id          = data.aws_appconfig_application.iam_config_prod[0].id
  environment_id          = data.aws_appconfig_environment.target_environment_prod[0].environment_id
  configuration_profile_id = data.aws_appconfig_configuration_profile.environment_profile_prod[0].configuration_profile_id
}
