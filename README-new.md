# AWS IAM Terraform Module with Variable-Based Environment Configuration

This Terraform module manages IAM policies and roles for specific AWS accounts and environments using separate variable files for each environment.

## Architecture

- **Separate environment configurations**: Each environment (dev, qa, prod) has its own `.tf` file with account-specific variables
- **Runtime environment selection**: Use a single `environment` variable to select which configuration to deploy
- **Account-specific settings**: Each environment file contains its own account ID, region, cross-account role, and IAM resources

## File Structure

```
aws-iam-terraform/
├── main.tf                                    # Main Terraform configuration
├── variables.tf                               # Variable definitions
├── locals.tf                                  # JSON configuration loading logic
├── backend.tf                                 # Backend configuration
├── outputs.tf                                 # Output definitions
├── config/
│   ├── dev.json                              # Development environment JSON config
│   ├── qa.json                               # QA environment JSON config
│   ├── prod.json                             # Production environment JSON config
│   └── README.md                             # Configuration documentation
├── backend/
│   ├── dev.hcl                               # Development backend config
│   ├── qa.hcl                                # QA backend config
│   └── prod.hcl                              # Production backend config
├── examples/
│   ├── dev.tfvars                            # Development deployment variables
│   ├── qa.tfvars                             # QA deployment variables
│   └── prod.tfvars                           # Production deployment variables
├── iam-policies/
│   ├── terraform-execution-policy.json       # Full Terraform IAM policy
│   ├── terraform-execution-policy-prod.json  # Restricted production IAM policy
│   └── README.md                             # IAM policy documentation
├── scripts/
│   ├── deploy.sh                             # Deployment helper script
│   └── setup-state-bucket.sh                # S3 state bucket setup script
├── docs/
│   └── backend-setup.md                      # Backend configuration guide
└── README.md                                  # Main project documentation
```

## Usage

### Deploy to Specific Environment

```bash
# Development
terraform apply -var-file="examples/dev.tfvars"

# QA
terraform apply -var-file="examples/qa.tfvars" 

# Production
terraform apply -var-file="examples/prod.tfvars"
```

### Using the Deployment Script

```bash
# Deploy to development
./scripts/deploy.sh dev

# Deploy to QA
./scripts/deploy.sh qa

# Deploy to production
./scripts/deploy.sh prod
```

## Environment Configuration

Each environment JSON file (`config/*.json`) contains:

- **Account Information**: Account ID, name, region
- **Cross-Account Role**: Role name for assuming access
- **IAM Policies**: Environment-specific IAM policies as key-value pairs
- **IAM Roles**: Environment-specific IAM roles as key-value pairs

### Example JSON Configuration Structure

```json
{
  "environment": "dev",
  "account_id": "345678901234",
  "account_name": "development",
  "region": "us-west-2",
  "cross_account_role": "DevelopmentAccountAccessRole",
  
  "iam_policies": {
    "policy_key": {
      "name": "PolicyName-Dev",
      "description": "Policy description",
      "document": "{\"Version\":\"2012-10-17\",\"Statement\":[...]}",
      "tags": {
        "Environment": "dev",
        "Team": "engineering"
      }
    }
  },
  
  "iam_roles": {
    "role_key": {
      "name": "RoleName-Dev",
      "description": "Role description",
      "assume_role_policy": "{\"Version\":\"2012-10-17\",\"Statement\":[...]}",
      "tags": {
        "Environment": "dev",
        "Type": "application"
      }
    }
  }
}
```

## Adding New Environments

1. **Create JSON config**: Add new `config/newenv.json` file with environment configuration
2. **Update variables.tf**: Add new environment to validation list
3. **Update locals.tf**: Add new environment to JSON loading logic
4. **Create tfvars**: Add `examples/newenv.tfvars` file
5. **Create backend config**: Add `backend/newenv.hcl` file
6. **Update deployment script**: Add new case statement

## Variables

- `environment`: Environment to deploy (dev, qa, prod) - **Required**
- `aws_region`: AWS region override (uses environment default if not specified)
- `cross_account_role_name`: Cross-account role name override

## Benefits

- **Simplified deployment**: Single variable controls entire environment
- **Clear separation**: Each environment has dedicated JSON configuration file
- **Easy maintenance**: Add/modify environments by editing JSON files
- **Type safety**: Terraform validates environment values and JSON structure
- **Version control friendly**: JSON files are easy to diff and merge
- **External tool integration**: JSON can be easily consumed by other tools and scripts
- **Human readable**: Key-value pairs are intuitive to read and modify

## Migration from JSON-based approach

If migrating from the previous JSON-based configuration:

1. Convert JSON configurations to Terraform variables in `environments/*.tf`
2. Update deployment scripts to use new tfvars files
3. Test with `terraform plan` before applying changes