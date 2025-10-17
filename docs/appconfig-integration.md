# AWS AppConfig Integration Guide

This guide explains how to store environment-specific configurations in AWS AppConfig and retrieve them at Terraform runtime.

## Overview

Instead of storing configurations in local JSON files, this setup uses AWS AppConfig to centrally manage environment configurations. This provides:

- **Centralized management**: All configurations stored in AWS
- **Version control**: Built-in versioning and rollback capabilities
- **Gradual rollouts**: Safe deployment with rollback options
- **Runtime retrieval**: Configurations loaded dynamically during Terraform execution
- **Validation**: AppConfig can validate configurations before deployment

## Architecture

```
Local JSON Files → AWS AppConfig → Terraform Data Sources → IAM Module
     ↓                   ↓                ↓                   ↓
config/*.json    AppConfig Service   data.aws_appconfig_*   IAM Resources
```

## Setup Process

### 1. Upload Configurations to AppConfig

Use the upload script to store your JSON configurations in AWS AppConfig:

```bash
# Upload all environment configurations
./scripts/upload-to-appconfig.sh all

# Upload specific environment
./scripts/upload-to-appconfig.sh dev
./scripts/upload-to-appconfig.sh qa
./scripts/upload-to-appconfig.sh prod
```

This creates:
- **Application**: `terraform-iam-config`
- **Environments**: `dev`, `qa`, `prod` (in AppConfig)
- **Configuration Profiles**: `dev-config`, `qa-config`, `prod-config`
- **Hosted Configurations**: JSON content from your config files

### 2. Verify Configurations

Retrieve and verify uploaded configurations:

```bash
# List all configurations
./scripts/get-from-appconfig.sh --list

# Retrieve specific environment configuration
./scripts/get-from-appconfig.sh dev
./scripts/get-from-appconfig.sh qa
./scripts/get-from-appconfig.sh prod
```

### 3. Deploy with Terraform

Run Terraform as usual - it will automatically retrieve configurations from AppConfig:

```bash
terraform apply -var="environment=dev"
```

## AppConfig Structure

### Application
- **Name**: `terraform-iam-config`
- **Description**: Terraform IAM configuration for environment-specific deployments
- **Tags**: `ManagedBy=terraform`, `Purpose=iam-configuration`

### Environments
Each Terraform environment has a corresponding AppConfig environment:
- `dev` → Development environment configuration
- `qa` → QA environment configuration  
- `prod` → Production environment configuration

### Configuration Profiles
Each environment has a configuration profile:
- `dev-config` → Development IAM configuration
- `qa-config` → QA IAM configuration
- `prod-config` → Production IAM configuration

### Configuration Content
The JSON content from your `config/*.json` files is stored as hosted configuration versions.

## Scripts

### upload-to-appconfig.sh

Uploads local JSON configurations to AWS AppConfig:

```bash
# Usage
./scripts/upload-to-appconfig.sh [environment]

# Examples
./scripts/upload-to-appconfig.sh all     # Upload all environments
./scripts/upload-to-appconfig.sh dev     # Upload dev only
./scripts/upload-to-appconfig.sh qa      # Upload qa only
./scripts/upload-to-appconfig.sh prod    # Upload prod only

# Help
./scripts/upload-to-appconfig.sh --help
```

**Features:**
- Creates AppConfig application if it doesn't exist
- Creates environments and configuration profiles
- Validates JSON before upload
- Starts deployments automatically
- Provides colored output and progress tracking

### get-from-appconfig.sh

Retrieves configurations from AWS AppConfig for verification:

```bash
# Usage
./scripts/get-from-appconfig.sh <environment>

# Examples
./scripts/get-from-appconfig.sh dev      # Retrieve dev configuration
./scripts/get-from-appconfig.sh qa       # Retrieve qa configuration
./scripts/get-from-appconfig.sh prod     # Retrieve prod configuration

# List all available configurations
./scripts/get-from-appconfig.sh --list

# Help
./scripts/get-from-appconfig.sh --help
```

**Features:**
- Retrieves deployed configuration content
- Pretty-prints JSON with syntax highlighting (if `jq` available)
- Saves retrieved content to local files for comparison
- Lists all available configurations

## Terraform Integration

### Data Sources (data.tf)

The Terraform configuration uses these data sources to retrieve configurations:

```hcl
# Get AppConfig application
data "aws_appconfig_application" "iam_config" {
  name = local.appconfig_app_name
}

# Get AppConfig environment
data "aws_appconfig_environment" "target_environment" {
  application_id = data.aws_appconfig_application.iam_config.id
  name          = var.environment
}

# Get configuration profile
data "aws_appconfig_configuration_profile" "environment_profile" {
  application_id = data.aws_appconfig_application.iam_config.id
  name          = "${var.environment}-config"
}

# Get deployed configuration
data "aws_appconfig_configuration" "environment_config" {
  application_id          = data.aws_appconfig_application.iam_config.id
  environment_id          = data.aws_appconfig_environment.target_environment.environment_id
  configuration_profile_id = data.aws_appconfig_configuration_profile.environment_profile.configuration_profile_id
}
```

### Configuration Loading (locals.tf)

```hcl
locals {
  # Parse JSON from AppConfig
  environment_config = jsondecode(data.aws_appconfig_configuration.environment_config.content)
  
  # Extract values
  account_id         = local.environment_config.account_id
  account_name       = local.environment_config.account_name
  region             = local.environment_config.region
  cross_account_role = local.environment_config.cross_account_role
}
```

## Prerequisites

### AWS CLI
- AWS CLI installed and configured
- Appropriate IAM permissions for AppConfig operations

### Required IAM Permissions

Your AWS credentials need these permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "appconfig:*"
      ],
      "Resource": "*"
    }
  ]
}
```

For production, use more restrictive permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "appconfig:GetApplication",
        "appconfig:ListApplications",
        "appconfig:GetEnvironment",
        "appconfig:ListEnvironments",
        "appconfig:GetConfigurationProfile",
        "appconfig:ListConfigurationProfiles",
        "appconfig:GetConfiguration",
        "appconfig:CreateApplication",
        "appconfig:CreateEnvironment",
        "appconfig:CreateConfigurationProfile",
        "appconfig:CreateHostedConfigurationVersion",
        "appconfig:StartDeployment"
      ],
      "Resource": "*"
    }
  ]
}
```

## Workflow

### Initial Setup
1. Create your environment JSON files in `config/`
2. Run `./scripts/upload-to-appconfig.sh all`
3. Verify with `./scripts/get-from-appconfig.sh --list`

### Configuration Updates
1. Modify your local JSON files in `config/`
2. Upload changes: `./scripts/upload-to-appconfig.sh <environment>`
3. AppConfig will deploy the new configuration gradually
4. Run Terraform to use the updated configuration

### Deployment
1. Run Terraform as usual: `terraform apply -var="environment=dev"`
2. Terraform retrieves configuration from AppConfig automatically
3. No changes to your existing Terraform workflow

## Benefits

### Centralized Management
- All configurations stored in AWS
- Single source of truth
- Cross-account access with proper IAM roles

### Version Control
- Built-in configuration versioning
- Easy rollback to previous versions
- Deployment history tracking

### Safe Rollouts
- Gradual deployment strategies
- Automatic rollback on validation failures
- Monitor deployment progress

### Dynamic Configuration
- Runtime configuration loading
- No need to rebuild or redeploy Terraform
- Configurations can be updated independently

### Validation
- AppConfig can validate JSON schema
- Prevent invalid configurations from being deployed
- Integration with AWS Lambda for custom validation

## Troubleshooting

### Common Issues

**Configuration not found:**
```bash
# Check if configurations are uploaded
./scripts/get-from-appconfig.sh --list

# Re-upload if needed
./scripts/upload-to-appconfig.sh dev
```

**Deployment in progress:**
- AppConfig deployments take time (gradual rollout)
- Check AWS Console for deployment status
- Wait for deployment to complete

**Invalid JSON:**
```bash
# Validate JSON locally
jq empty config/dev.json

# Fix JSON syntax and re-upload
./scripts/upload-to-appconfig.sh dev
```

**Permission errors:**
- Ensure AWS CLI is configured with appropriate permissions
- Check IAM policies for AppConfig access

### Debugging

Enable Terraform debug logging:
```bash
export TF_LOG=DEBUG
terraform plan -var="environment=dev"
```

Check AppConfig deployment status:
```bash
aws appconfig list-deployments \
  --application-id <app-id> \
  --environment-id <env-id>
```

## Migration Guide

### From Local JSON Files

1. **Keep existing files**: Your `config/*.json` files remain as source of truth
2. **Upload to AppConfig**: Run upload script to store in AWS
3. **Update Terraform**: The changes are already in place with data sources
4. **Test**: Verify configurations are loaded correctly
5. **Optional cleanup**: You can remove local JSON files after verification

### From Previous Versions

If migrating from the previous Terraform configuration:

1. **Backup current state**: `terraform state pull > backup.tfstate`
2. **Upload configurations**: `./scripts/upload-to-appconfig.sh all`
3. **Test data sources**: `terraform plan -var="environment=dev"`
4. **Apply gradually**: Test with dev first, then qa, then prod

This integration provides a robust, scalable way to manage environment configurations while maintaining the simplicity of your existing Terraform workflow.