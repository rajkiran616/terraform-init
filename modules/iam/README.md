# IAM Module

This module creates IAM policies and roles for a specific environment. It's designed to be environment-agnostic and uses the provider passed from the parent configuration.

## Features

- Creates IAM policies from configuration
- Creates IAM roles from configuration
- Automatically tags all resources with environment and account information
- Provides comprehensive outputs for created resources

## Usage

```hcl
module "iam_environment" {
  source = "./modules/iam"
  
  providers = {
    aws = aws.target_account
  }
  
  environment   = "dev"
  account_id    = "123456789012"
  account_name  = "development"
  iam_policies  = var.iam_policies
  iam_roles     = var.iam_roles
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| environment | Environment name | `string` | n/a | yes |
| account_id | AWS Account ID | `string` | n/a | yes |
| account_name | AWS Account name | `string` | n/a | yes |
| iam_policies | Map of IAM policies to create | `map(object)` | `{}` | no |
| iam_roles | Map of IAM roles to create | `map(object)` | `{}` | no |

### IAM Policy Object Structure

```hcl
{
  name        = string  # IAM policy name
  description = string  # Policy description
  document    = string  # IAM policy document as JSON string
  tags        = map(string)  # Additional tags
}
```

### IAM Role Object Structure

```hcl
{
  name               = string  # IAM role name
  description        = string  # Role description
  assume_role_policy = string  # Trust policy as JSON string
  tags               = map(string)  # Additional tags
}
```

## Outputs

| Name | Description |
|------|-------------|
| policy_arns | Map of policy keys to their ARNs |
| policy_names | Map of policy keys to their names |
| role_arns | Map of role keys to their ARNs |
| role_names | Map of role keys to their names |
| created_policies | Detailed information about created policies |
| created_roles | Detailed information about created roles |

## Automatic Tagging

All resources created by this module are automatically tagged with:

- `ManagedBy`: "terraform"
- `Account`: Account name
- `AccountId`: AWS Account ID
- `Environment`: Environment name
- `PolicyKey` or `RoleKey`: The key used in the configuration

Additional tags from the input configuration are merged with these automatic tags.

## Examples

### Basic Policy Creation

```hcl
module "iam_dev" {
  source = "./modules/iam"
  
  providers = {
    aws = aws.dev
  }
  
  environment  = "dev"
  account_id   = "345678901234"
  account_name = "development"
  
  iam_policies = {
    s3_access = {
      name        = "S3Access-Dev"
      description = "S3 access for development"
      document    = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect = "Allow"
          Action = ["s3:*"]
          Resource = ["arn:aws:s3:::dev-*", "arn:aws:s3:::dev-*/*"]
        }]
      })
      tags = {
        Service = "s3"
        Team    = "engineering"
      }
    }
  }
  
  iam_roles = {
    app_role = {
      name        = "AppRole-Dev"
      description = "Application role for development"
      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect = "Allow"
          Principal = { Service = ["lambda.amazonaws.com"] }
          Action = "sts:AssumeRole"
        }]
      })
      tags = {
        Type = "application"
      }
    }
  }
}
```

### Accessing Outputs

```hcl
# Get policy ARNs
output "dev_policy_arns" {
  value = module.iam_dev.policy_arns
}

# Get role ARNs
output "dev_role_arns" {
  value = module.iam_dev.role_arns
}

# Get detailed information
output "dev_created_policies" {
  value = module.iam_dev.created_policies
}
```

## Provider Requirements

This module requires:
- Terraform >= 1.0
- AWS Provider >= 5.0

The AWS provider must be configured with appropriate permissions to create IAM resources in the target account.