# AWS IAM Terraform Module with Variable-Based Environment Configuration

This Terraform module manages IAM policies and roles for specific AWS accounts and environments using separate variable files for each environment.

## Architecture

- **Separate environment configurations**: Each environment (dev, qa, prod) has its own `.tf` file with account-specific variables
- **Runtime environment selection**: Use a single `environment` variable to select which configuration to deploy
- **Account-specific settings**: Each environment file contains its own account ID, region, cross-account role, and IAM resources

## File Structure

```
aws-iam-terraform/
├── main.tf                      # Main Terraform configuration
├── variables.tf                 # Variable definitions
├── locals.tf                    # Environment selection logic
├── environments/
│   ├── dev.tf                  # Development environment config
│   ├── qa.tf                   # QA/Staging environment config  
│   └── prod.tf                 # Production environment config
├── examples/
│   ├── dev.tfvars             # Development deployment variables
│   ├── qa.tfvars              # QA deployment variables
│   └── prod.tfvars            # Production deployment variables
└── scripts/
    └── deploy.sh              # Deployment helper script
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

Each environment file (`environments/*.tf`) contains:

- **Account Information**: Account ID, name, region
- **Cross-Account Role**: Role name for assuming access
- **IAM Policies**: Environment-specific IAM policies
- **IAM Roles**: Environment-specific IAM roles

### Example Environment File Structure

```hcl
locals {
  dev_config = {
    environment = "dev"
    account_id  = "345678901234"
    account_name = "development"
    region = "us-west-2"
    cross_account_role = "DevelopmentAccountAccessRole"
    
    iam_policies = {
      policy_name = {
        name        = "PolicyName"
        description = "Policy description"
        document    = jsonencode({ /* policy document */ })
        tags = { /* policy tags */ }
      }
    }
    
    iam_roles = {
      role_name = {
        name               = "RoleName"
        description        = "Role description"
        assume_role_policy = jsonencode({ /* trust policy */ })
        tags = { /* role tags */ }
      }
    }
  }
}
```

## Adding New Environments

1. **Create environment file**: Add new `environments/newenv.tf` file
2. **Update variables.tf**: Add new environment to validation list
3. **Update locals.tf**: Add new environment to selection logic
4. **Create tfvars**: Add `examples/newenv.tfvars` file
5. **Update deployment script**: Add new case statement

## Variables

- `environment`: Environment to deploy (dev, qa, prod) - **Required**
- `aws_region`: AWS region override (uses environment default if not specified)
- `cross_account_role_name`: Cross-account role name override

## Benefits

- **Simplified deployment**: Single variable controls entire environment
- **Clear separation**: Each environment has dedicated configuration
- **Easy maintenance**: Add/modify environments by editing single files
- **Type safety**: Terraform validates environment values
- **No JSON parsing**: Pure Terraform configuration

## Migration from JSON-based approach

If migrating from the previous JSON-based configuration:

1. Convert JSON configurations to Terraform variables in `environments/*.tf`
2. Update deployment scripts to use new tfvars files
3. Test with `terraform plan` before applying changes