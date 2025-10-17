# AppConfig Per-Account Setup Guide

This guide explains how to set up AWS AppConfig in each target account to work with environment-specific providers.

## Overview

With the current configuration, each environment uses its own AWS provider and retrieves AppConfig data from the same account where the IAM resources will be created. This provides better isolation and security.

## Architecture

```
Account Structure:
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   Dev Account   │  │   QA Account    │  │  Prod Account   │
│  345678901234   │  │  234567890123   │  │  123456789012   │
│                 │  │                 │  │                 │
│ AppConfig Apps  │  │ AppConfig Apps  │  │ AppConfig Apps  │
│ ├─ dev-config   │  │ ├─ qa-config    │  │ ├─ prod-config  │
│ └─ IAM Resources│  │ └─ IAM Resources│  │ └─ IAM Resources│
└─────────────────┘  └─────────────────┘  └─────────────────┘
```

## Setup Process

### 1. Configure AWS Profiles or Roles

Set up AWS CLI profiles for each account:

**Option A: AWS CLI Profiles**
```bash
# Configure profiles for each account
aws configure --profile dev-profile
aws configure --profile qa-profile
aws configure --profile prod-profile
```

**Option B: Assume Role Configuration**
```bash
# ~/.aws/config
[profile dev-profile]
role_arn = arn:aws:iam::345678901234:role/DevelopmentAccountAccessRole
source_profile = default

[profile qa-profile]
role_arn = arn:aws:iam::234567890123:role/QAAccountAccessRole
source_profile = default

[profile prod-profile]
role_arn = arn:aws:iam::123456789012:role/ProductionAccountAccessRole
source_profile = default
```

### 2. Upload Configurations per Account

Upload AppConfig to each specific account:

```bash
# Upload to development account
AWS_PROFILE=dev-profile ./scripts/upload-to-appconfig.sh dev

# Upload to QA account
AWS_PROFILE=qa-profile ./scripts/upload-to-appconfig.sh qa

# Upload to production account
AWS_PROFILE=prod-profile ./scripts/upload-to-appconfig.sh prod
```

### 3. Verify Configurations

Check configurations in each account:

```bash
# Verify dev account
AWS_PROFILE=dev-profile ./scripts/get-from-appconfig.sh dev

# Verify QA account
AWS_PROFILE=qa-profile ./scripts/get-from-appconfig.sh qa

# Verify prod account
AWS_PROFILE=prod-profile ./scripts/get-from-appconfig.sh prod
```

## Current Terraform Configuration

The current `data.tf` file uses environment-specific providers:

```hcl
# Development AppConfig Data Sources
data "aws_appconfig_application" "iam_config_dev" {
  count    = var.environment == "dev" ? 1 : 0
  provider = aws.dev  # Uses dev account provider
  name     = local.appconfig_app_name
}

# QA AppConfig Data Sources
data "aws_appconfig_application" "iam_config_qa" {
  count    = var.environment == "qa" ? 1 : 0
  provider = aws.qa   # Uses qa account provider
  name     = local.appconfig_app_name
}

# Production AppConfig Data Sources
data "aws_appconfig_application" "iam_config_prod" {
  count    = var.environment == "prod" ? 1 : 0
  provider = aws.prod # Uses prod account provider
  name     = local.appconfig_app_name
}
```

## Benefits of Per-Account AppConfig

### 1. **Account Isolation**
- Each account manages its own configuration
- No cross-account dependencies for configuration retrieval
- Reduced blast radius for configuration issues

### 2. **Security**
- Configuration access limited to account boundaries
- Easier to implement least-privilege access
- Configuration changes don't affect other environments

### 3. **Compliance**
- Better alignment with security policies
- Clear audit trails per account
- Environment-specific access controls

## Updated Upload Script Usage

Use environment variables to specify AWS profiles:

```bash
# Method 1: Using AWS_PROFILE environment variable
export AWS_PROFILE=dev-profile
./scripts/upload-to-appconfig.sh dev

# Method 2: Using AWS CLI profiles directly
AWS_PROFILE=dev-profile ./scripts/upload-to-appconfig.sh dev
AWS_PROFILE=qa-profile ./scripts/upload-to-appconfig.sh qa
AWS_PROFILE=prod-profile ./scripts/upload-to-appconfig.sh prod

# Method 3: Using assume role
aws sts assume-role --role-arn arn:aws:iam::345678901234:role/TerraformRole \
  --role-session-name terraform-session > /tmp/creds
export AWS_ACCESS_KEY_ID=$(jq -r '.Credentials.AccessKeyId' /tmp/creds)
export AWS_SECRET_ACCESS_KEY=$(jq -r '.Credentials.SecretAccessKey' /tmp/creds)
export AWS_SESSION_TOKEN=$(jq -r '.Credentials.SessionToken' /tmp/creds)
./scripts/upload-to-appconfig.sh dev
```

## Terraform Deployment

The Terraform deployment workflow remains unchanged:

```bash
# Deploy to development (uses aws.dev provider)
terraform apply -var="environment=dev"

# Deploy to QA (uses aws.qa provider)
terraform apply -var="environment=qa"

# Deploy to production (uses aws.prod provider)
terraform apply -var="environment=prod"
```

## Automation Examples

### CI/CD Pipeline

```yaml
# GitHub Actions example
jobs:
  upload-config:
    steps:
      - name: Upload Dev Config
        run: |
          aws sts assume-role --role-arn ${{ secrets.DEV_ROLE_ARN }} \
            --role-session-name github-actions > /tmp/dev-creds
          export AWS_ACCESS_KEY_ID=$(jq -r '.Credentials.AccessKeyId' /tmp/dev-creds)
          export AWS_SECRET_ACCESS_KEY=$(jq -r '.Credentials.SecretAccessKey' /tmp/dev-creds)
          export AWS_SESSION_TOKEN=$(jq -r '.Credentials.SessionToken' /tmp/dev-creds)
          ./scripts/upload-to-appconfig.sh dev
      
      - name: Deploy Dev
        run: terraform apply -var="environment=dev" -auto-approve
```

### Batch Upload Script

Create a helper script for uploading all environments:

```bash
#!/bin/bash
# scripts/upload-all-environments.sh

set -e

echo "Uploading configurations to all accounts..."

# Development
echo "=== Development Account ==="
AWS_PROFILE=dev-profile ./scripts/upload-to-appconfig.sh dev

# QA
echo "=== QA Account ==="
AWS_PROFILE=qa-profile ./scripts/upload-to-appconfig.sh qa

# Production
echo "=== Production Account ==="
AWS_PROFILE=prod-profile ./scripts/upload-to-appconfig.sh prod

echo "All configurations uploaded successfully!"
```

## Troubleshooting

### 1. **Permission Issues**

Ensure each profile has AppConfig permissions:

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

### 2. **Cross-Account Role Issues**

Verify assume role configuration:

```bash
# Test assume role
aws sts assume-role --role-arn arn:aws:iam::345678901234:role/TerraformRole \
  --role-session-name test-session
```

### 3. **AppConfig Application Not Found**

Check if application exists in the correct account:

```bash
AWS_PROFILE=dev-profile aws appconfig list-applications
```

### 4. **Terraform Data Source Issues**

Enable debug logging:

```bash
export TF_LOG=DEBUG
terraform plan -var="environment=dev"
```

## Migration from Central AppConfig

If migrating from a central AppConfig setup:

1. **Backup existing configurations**:
   ```bash
   ./scripts/get-from-appconfig.sh --list > backup-configs.txt
   ```

2. **Upload to each account**:
   ```bash
   AWS_PROFILE=dev-profile ./scripts/upload-to-appconfig.sh dev
   AWS_PROFILE=qa-profile ./scripts/upload-to-appconfig.sh qa
   AWS_PROFILE=prod-profile ./scripts/upload-to-appconfig.sh prod
   ```

3. **Update Terraform configuration**: Already done in `data.tf`

4. **Test each environment**:
   ```bash
   terraform plan -var="environment=dev"
   terraform plan -var="environment=qa"
   terraform plan -var="environment=prod"
   ```

5. **Clean up central AppConfig** (optional): Remove old central application

This per-account approach provides better isolation, security, and aligns with AWS best practices for multi-account architectures.