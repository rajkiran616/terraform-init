# AWS IAM Terraform Module with Environment-Specific Configuration

This Terraform module manages IAM policies and roles across multiple AWS accounts and environments using a JSON configuration approach. It supports both organization-wide deployment and environment-specific targeting.

## What it does

- Loads IAM configurations from JSON files organized by account and environment
- Creates IAM policies and roles in specified accounts/environments
- Supports selective deployment to specific accounts or environments
- Tags all resources with comprehensive metadata

## Features

- **Environment-based configuration**: Store IAM policies and roles in JSON files organized by account and environment
- **Selective deployment**: Deploy to specific accounts and environments or all at once
- **Cross-account support**: Automatically assumes roles in target accounts
- **Flexible structure**: Support for multiple environments (dev, staging, prod) per account

## Prerequisites

1. AWS credentials configured with appropriate permissions
2. Cross-account roles configured in target accounts (e.g., `OrganizationAccountAccessRole`)
3. JSON configuration file with environment definitions

## Quick Start

1. **Review the JSON configuration:**
   ```bash
   cat config/environments.json
   ```

2. **Deploy to specific environment:**
   ```bash
   # Development
   terraform apply -var-file="examples/dev.tfvars"
   
   # Staging  
   terraform apply -var-file="examples/staging.tfvars"
   
   # Production
   terraform apply -var-file="examples/prod.tfvars"
   ```

3. **Or deploy to all environments:**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Configuration

- `aws_region`: AWS region (default: us-east-1)
- `cross_account_role_name`: Role to assume in member accounts (default: OrganizationAccountAccessRole)
- `iam_policies`: Map of policies to create

## Examples

### S3 Read-Only Policy
```hcl
"s3-logs-read" = {
  name        = "terraform-s3-logs-read"
  description = "Read access to logs bucket"
  document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::company-logs",
          "arn:aws:s3:::company-logs/*"
        ]
      }
    ]
  })
}
```

### Lambda Invoke Policy
```hcl
"lambda-invoke" = {
  name        = "terraform-lambda-invoke"
  description = "Invoke specific Lambda functions"
  document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "lambda:InvokeFunction"
        Resource = [
          "arn:aws:lambda:*:*:function:my-function-*"
        ]
      }
    ]
  })
}
```

## Important Notes

- This only creates NEW policies - it won't touch existing ones
- All policies get created in ALL accounts in your organization
- All policies are tagged with `ManagedBy = "terraform"`
- Policy names must be unique within each account

## View Results

After applying, you can see what was created:
```bash
terraform output created_policies
terraform output organization_accounts
```