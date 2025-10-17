# Environment Configuration Files

This directory contains JSON configuration files for each environment. Each file defines environment-specific settings, IAM policies, and IAM roles as key-value pairs.

## File Structure

```
config/
├── dev.json    # Development environment configuration
├── qa.json     # QA/Staging environment configuration  
├── prod.json   # Production environment configuration
└── README.md   # This documentation
```

## JSON Configuration Format

Each environment JSON file follows this structure:

```json
{
  "environment": "env_name",
  "account_id": "AWS_ACCOUNT_ID",
  "account_name": "descriptive_name",
  "region": "aws_region",
  "cross_account_role": "CrossAccountRoleName",
  
  "iam_policies": {
    "policy_key": {
      "name": "PolicyName",
      "description": "Policy description",
      "document": "JSON_POLICY_DOCUMENT_AS_STRING",
      "tags": {
        "key": "value"
      }
    }
  },
  
  "iam_roles": {
    "role_key": {
      "name": "RoleName",
      "description": "Role description", 
      "assume_role_policy": "JSON_TRUST_POLICY_AS_STRING",
      "tags": {
        "key": "value"
      }
    }
  }
}
```

## Configuration Fields

### Top-Level Fields

- **`environment`**: Environment identifier (dev, qa, prod)
- **`account_id`**: AWS account ID for this environment
- **`account_name`**: Descriptive name for the account
- **`region`**: Default AWS region for resources
- **`cross_account_role`**: IAM role name for cross-account access

### IAM Policy Structure

Each policy in `iam_policies` object contains:

- **`name`**: IAM policy name (must be unique within account)
- **`description`**: Human-readable policy description
- **`document`**: IAM policy document as JSON string
- **`tags`**: Key-value pairs for resource tagging

### IAM Role Structure

Each role in `iam_roles` object contains:

- **`name`**: IAM role name (must be unique within account)
- **`description`**: Human-readable role description  
- **`assume_role_policy`**: Trust policy as JSON string
- **`tags`**: Key-value pairs for resource tagging

## Usage

### Loading Configuration

The configuration is automatically loaded based on the `environment` variable:

```bash
# Load development configuration
terraform apply -var="environment=dev"

# Load QA configuration  
terraform apply -var="environment=qa"

# Load production configuration
terraform apply -var="environment=prod"
```

### Adding New Policies

To add a new IAM policy to an environment:

1. **Edit the environment JSON file** (e.g., `dev.json`)
2. **Add policy to `iam_policies` section**:

```json
"iam_policies": {
  "existing_policy": { ... },
  "new_policy_key": {
    "name": "NewPolicyName-Dev",
    "description": "Description of new policy",
    "document": "{\"Version\":\"2012-10-17\",\"Statement\":[...]}",
    "tags": {
      "Environment": "dev",
      "Service": "service_name"
    }
  }
}
```

3. **Apply changes**: `terraform apply -var="environment=dev"`

### Adding New Roles

To add a new IAM role to an environment:

1. **Edit the environment JSON file**
2. **Add role to `iam_roles` section**:

```json
"iam_roles": {
  "existing_role": { ... },
  "new_role_key": {
    "name": "NewRoleName-Dev", 
    "description": "Description of new role",
    "assume_role_policy": "{\"Version\":\"2012-10-17\",\"Statement\":[...]}",
    "tags": {
      "Environment": "dev",
      "Type": "service_type"
    }
  }
}
```

3. **Apply changes**: `terraform apply -var="environment=dev"`

## JSON Policy Documents

Policy and trust policy documents are stored as escaped JSON strings within the configuration. Here are some examples:

### S3 Access Policy

```json
"document": "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"s3:GetObject\",\"s3:PutObject\"],\"Resource\":[\"arn:aws:s3:::bucket-name/*\"]}]}"
```

### Lambda Execution Trust Policy

```json
"assume_role_policy": "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":[\"lambda.amazonaws.com\"]},\"Action\":\"sts:AssumeRole\"}]}"
```

### Multi-Service Trust Policy

```json
"assume_role_policy": "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":[\"ec2.amazonaws.com\",\"lambda.amazonaws.com\",\"ecs-tasks.amazonaws.com\"]},\"Action\":\"sts:AssumeRole\"}]}"
```

## Best Practices

### Naming Conventions

- **Policies**: `ServiceName-Environment` (e.g., `S3Access-Dev`)
- **Roles**: `ServiceRole-Environment` (e.g., `LambdaExecutionRole-Prod`)
- **Keys**: Use lowercase with underscores (e.g., `s3_access_policy`)

### Environment Differentiation

- **Development**: Full permissions for rapid development
- **QA**: Moderate permissions for testing
- **Production**: Restricted permissions following least privilege

### JSON Formatting

- **Escape quotes**: Use `\"` for quotes within JSON strings
- **Validate syntax**: Use online JSON validators before applying
- **Keep readable**: Use consistent formatting and indentation

### Security Considerations

- **Least Privilege**: Grant minimum required permissions
- **Environment Separation**: Use different policies per environment
- **Resource Restrictions**: Use ARN patterns to limit resource access
- **Regular Audits**: Review and update policies regularly

## Validation

### JSON Syntax Validation

```bash
# Validate JSON syntax
jq empty config/dev.json && echo "Valid JSON" || echo "Invalid JSON"

# Pretty print JSON
jq . config/dev.json
```

### Terraform Validation

```bash
# Validate Terraform configuration
terraform validate

# Plan deployment
terraform plan -var="environment=dev"
```

## Troubleshooting

### Common Issues

1. **Invalid JSON**: Check for missing quotes, commas, or brackets
2. **Policy syntax errors**: Validate IAM policy documents separately  
3. **Duplicate names**: Ensure policy/role names are unique within account
4. **Missing escapes**: Ensure quotes in JSON strings are properly escaped

### Testing Changes

1. **Start with development**: Test changes in dev environment first
2. **Use terraform plan**: Always plan before applying changes
3. **Validate policies**: Use AWS Policy Simulator to test permissions
4. **Monitor deployments**: Check AWS CloudTrail for any errors

## Examples

See the existing `dev.json`, `qa.json`, and `prod.json` files for complete configuration examples with various policy types and role configurations.