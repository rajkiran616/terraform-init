# IAM Management Module

🔐 **Comprehensive IAM management module for multi-account AWS organizations**

## Overview

This module provides a standardized way to create and manage IAM policies, roles, and instance profiles across multiple AWS accounts with proper naming conventions, tagging, and security best practices.

## Features

- ✅ **Policy Management**: Create custom IAM policies with JSON documents
- ✅ **Role Management**: Create IAM roles with assume role policies
- ✅ **Policy Attachments**: Automatically attach policies to roles (custom + AWS managed)
- ✅ **Instance Profiles**: Create EC2 instance profiles when needed
- ✅ **Standardized Naming**: Consistent naming with environment prefixes
- ✅ **Comprehensive Tagging**: Automated tagging for all resources
- ✅ **AWS Managed Support**: Reference AWS managed policies by name or ARN

## Usage

### Basic Example

```hcl
module "iam_management" {
  source = "./modules/iam-management"
  
  environment   = "development"
  account_id    = "123456789012"
  region        = "us-east-1"
  project_name  = "my-project"
  
  policy_prefix = "dev-"
  role_prefix   = "dev-"
  
  policies = {
    "s3-access" = {
      description     = "S3 access for development"
      policy_document = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = ["s3:GetObject", "s3:PutObject"]
            Resource = "arn:aws:s3:::dev-bucket/*"
          }
        ]
      })
    }
  }
  
  roles = {
    "lambda-role" = {
      description              = "Lambda execution role"
      max_session_duration    = 3600
      create_instance_profile = false
      assume_role_policy      = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Principal = { Service = "lambda.amazonaws.com" }
            Action = "sts:AssumeRole"
          }
        ]
      })
      attached_policies = [
        "s3-access",                          # Custom policy
        "AWSLambdaBasicExecutionRole"        # AWS managed policy
      ]
    }
  }
  
  common_tags = {
    Environment = "development"
    Project     = "my-project"
    ManagedBy   = "Terraform"
  }
}
```

### Policy Examples

#### S3 Access Policy
```hcl
"s3-bucket-access" = {
  description = "Access to specific S3 buckets"
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::my-bucket/*",
          "arn:aws:s3:::another-bucket/*"
        ]
      },
      {
        Effect = "Allow"
        Action = ["s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::my-bucket",
          "arn:aws:s3:::another-bucket"
        ]
      }
    ]
  })
}
```

#### CloudWatch Logs Policy
```hcl
"cloudwatch-logs" = {
  description = "CloudWatch Logs access"
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}
```

#### Secrets Manager Policy
```hcl
"secrets-manager-access" = {
  description = "Secrets Manager read access"
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:*:*:secret:app/*"
      }
    ]
  })
}
```

### Role Examples

#### Lambda Execution Role
```hcl
"lambda-execution-role" = {
  description              = "Role for Lambda function execution"
  max_session_duration    = 3600
  create_instance_profile = false
  assume_role_policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action = "sts:AssumeRole"
      }
    ]
  })
  attached_policies = [
    "cloudwatch-logs",
    "secrets-manager-access",
    "AWSLambdaBasicExecutionRole"
  ]
}
```

#### EC2 Instance Role
```hcl
"ec2-instance-role" = {
  description              = "Role for EC2 instances"
  max_session_duration    = 7200
  create_instance_profile = true  # Creates instance profile automatically
  assume_role_policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action = "sts:AssumeRole"
      }
    ]
  })
  attached_policies = [
    "s3-bucket-access",
    "cloudwatch-logs",
    "CloudWatchAgentServerPolicy"
  ]
}
```

#### Cross-Account Role
```hcl
"cross-account-role" = {
  description              = "Role that can be assumed from another account"
  max_session_duration    = 3600
  create_instance_profile = false
  assume_role_policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { AWS = "arn:aws:iam::111111111111:root" }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "unique-external-id"
          }
        }
      }
    ]
  })
  attached_policies = [
    "s3-bucket-access"
  ]
}
```

## Policy Attachment Types

The module supports three types of policy attachments:

### 1. Custom Policies (defined in the same module)
```hcl
attached_policies = [
  "my-custom-policy"  # References policies defined in this module
]
```

### 2. AWS Managed Policies (by name)
```hcl
attached_policies = [
  "AWSLambdaBasicExecutionRole",
  "CloudWatchAgentServerPolicy",
  "PowerUserAccess"
]
```

### 3. Policy ARNs (full ARN)
```hcl
attached_policies = [
  "arn:aws:iam::123456789012:policy/MyCustomPolicy",
  "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
]
```

## Outputs

The module provides comprehensive outputs for integration:

```hcl
# Policy ARNs
output "policy_arns" {
  value = module.iam_management.policy_arns
  # Returns: { "policy-name" = "arn:aws:iam::account:policy/prefix-policy-name" }
}

# Role ARNs  
output "role_arns" {
  value = module.iam_management.role_arns
  # Returns: { "role-name" = "arn:aws:iam::account:role/prefix-role-name" }
}

# Instance Profile ARNs
output "instance_profile_arns" {
  value = module.iam_management.instance_profile_arns
  # Returns: { "role-name" = "arn:aws:iam::account:instance-profile/prefix-role-name-instance-profile" }
}
```

## Variables Reference

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `environment` | string | - | Environment name (required) |
| `account_id` | string | - | AWS Account ID (required) |
| `region` | string | - | AWS region (required) |
| `project_name` | string | - | Project name (required) |
| `policy_prefix` | string | `""` | Prefix for policy names |
| `role_prefix` | string | `""` | Prefix for role names |
| `common_tags` | map(string) | `{}` | Tags applied to all resources |
| `policies` | map(object) | `{}` | Map of policies to create |
| `roles` | map(object) | `{}` | Map of roles to create |

## Resource Naming

Resources are named using the following pattern:

- **Policies**: `{policy_prefix}{policy_key}`
- **Roles**: `{role_prefix}{role_key}`
- **Instance Profiles**: `{role_prefix}{role_key}-instance-profile`

Example with `dev-` prefix:
- Policy: `dev-s3-access`
- Role: `dev-lambda-role`
- Instance Profile: `dev-ec2-role-instance-profile`

## Importing Existing Resources

To import existing IAM resources:

### 1. Add to Configuration
First, add the resource to your configuration:

```hcl
policies = {
  "existing-policy" = {
    description = "Existing policy description"
    policy_document = jsonencode({...}) # Current policy document
  }
}
```

### 2. Import into State
```bash
# Import existing policy
terraform import 'module.iam_management.aws_iam_policy.custom["existing-policy"]' arn:aws:iam::ACCOUNT:policy/ExistingPolicyName

# Import existing role  
terraform import 'module.iam_management.aws_iam_role.custom["existing-role"]' ExistingRoleName
```

### 3. Using the Import Script
```bash
# List existing resources
./scripts/import-existing-resources.sh dev --list-only

# Import specific policy
./scripts/import-existing-resources.sh dev --policy=ExistingPolicy

# Import specific role
./scripts/import-existing-resources.sh dev --role=ExistingRole
```

## Best Practices

### 1. Policy Design
- ✅ Use least privilege principle
- ✅ Scope resources appropriately
- ✅ Use conditions when possible
- ✅ Separate concerns into multiple policies

### 2. Naming Conventions
- ✅ Use environment prefixes (`dev-`, `prod-`)
- ✅ Use descriptive names
- ✅ Keep names consistent across accounts
- ✅ Avoid special characters

### 3. Role Configuration
- ✅ Set appropriate session durations
- ✅ Only create instance profiles when needed
- ✅ Use specific service principals
- ✅ Add external IDs for cross-account roles

### 4. Tagging Strategy
```hcl
common_tags = {
  Environment = "production"
  Project     = "my-project"  
  Owner       = "platform-team"
  CostCenter  = "engineering"
  ManagedBy   = "Terraform"
}
```

## Troubleshooting

### Common Issues

**Policy attachment fails**
```
Error: cannot attach policy: policy not found
```
- Ensure custom policies are defined in the `policies` map
- Check AWS managed policy names are correct
- Verify ARNs are complete and valid

**Role assumption fails**
```
Error: cannot assume role
```
- Check assume role policy syntax
- Verify service principals are correct
- Ensure trust relationships are properly configured

**Import fails**
```
Error: resource not found
```
- Verify resource names match exactly
- Check resource exists in the target account
- Ensure proper permissions for import operation

This module provides a robust foundation for managing IAM resources across your multi-account organization with proper security, naming, and operational practices.