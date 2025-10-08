# Multi-Account Terraform Organization

🚀 **Production-ready multi-account Terraform setup with automated role assumption, workspace management, and dedicated backends.**

## 🏗️ Project Structure

```
terraform-multi-account-organization/
├── README.md                           # This file
├── scripts/
│   ├── assume-role.sh                  # Automated role assumption script
│   ├── setup-workspace.sh              # Workspace management script
│   ├── deploy-to-account.sh            # End-to-end deployment script
│   └── import-existing-resources.sh    # Import existing IAM resources
├── configs/
│   ├── accounts.yaml                   # Account configuration
│   ├── dev.tfvars                     # Development variables
│   ├── qa.tfvars                      # QA variables  
│   ├── test.tfvars                    # Test variables
│   └── prod.tfvars                    # Production variables
├── modules/
│   └── iam-management/                # IAM management module
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── README.md                  # Module usage guide
├── backends/
│   ├── dev-backend.hcl               # Dev backend config
│   ├── qa-backend.hcl                # QA backend config
│   ├── test-backend.hcl              # Test backend config  
│   └── prod-backend.hcl              # Prod backend config
├── main.tf                           # Root configuration
├── variables.tf                      # Root variables
├── outputs.tf                        # Root outputs
└── terraform.tf                      # Terraform settings and providers
```

## 🎯 Key Features

- **🔐 Automated Role Assumption**: Script-based role switching with temporary credentials
- **🏢 Organization Integration**: Seamless AWS Organizations account management
- **📊 Workspace Management**: Terraform workspaces per account for isolation
- **🗃️ Dedicated Backends**: Separate state storage per account for security
- **📦 Modular Design**: Reusable IAM management module
- **🔄 Import Support**: Import existing IAM resources into Terraform state
- **⚡ Automation Scripts**: One-command deployment to any account

## 🚀 Quick Start

### 1. Initial Setup
```bash
# Clone and setup
git clone <repository>
cd terraform-multi-account-organization

# Configure your accounts
vim configs/accounts.yaml

# Set up backends for each account
./scripts/setup-workspace.sh --init-all
```

### 2. Deploy to Specific Account
```bash
# Deploy IAM resources to development account
./scripts/deploy-to-account.sh dev

# Deploy to production with confirmation
./scripts/deploy-to-account.sh prod --confirm
```

### 3. Import Existing Resources
```bash
# Import existing IAM policies and roles
./scripts/import-existing-resources.sh dev
```

## 📋 Prerequisites

- AWS CLI configured with organization master account access
- Terraform >= 1.6
- `jq` installed for JSON processing
- Cross-account roles configured in target accounts
- Organization account structure set up

## 🔧 Configuration

### Account Configuration (`configs/accounts.yaml`)
```yaml
accounts:
  dev:
    account_id: "111111111111"
    role_name: "OrganizationAccountAccessRole"
    region: "us-east-1"
    environment: "development"
  qa:
    account_id: "222222222222"  
    role_name: "OrganizationAccountAccessRole"
    region: "us-east-1"
    environment: "qa"
  test:
    account_id: "333333333333"
    role_name: "OrganizationAccountAccessRole"
    region: "us-west-2"
    environment: "test"
  prod:
    account_id: "444444444444"
    role_name: "OrganizationAccountAccessRole"
    region: "us-east-1"
    environment: "production"
```

## 🔐 Role Assumption Workflow

The project uses automated role assumption:

1. **Master Account**: Your local credentials
2. **Cross-Account Role**: `OrganizationAccountAccessRole` in each account
3. **Temporary Credentials**: Generated per deployment
4. **Workspace Isolation**: Separate Terraform workspace per account

## 📚 Module Usage

### IAM Management Module

```hcl
module "iam_management" {
  source = "./modules/iam-management"
  
  environment = var.environment
  policies = {
    "lambda-execution" = {
      description = "Lambda execution permissions"
      policy_document = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "logs:CreateLogGroup",
              "logs:CreateLogStream", 
              "logs:PutLogEvents"
            ]
            Resource = "arn:aws:logs:*:*:*"
          }
        ]
      })
    }
  }
  
  roles = {
    "lambda-execution-role" = {
      description = "Role for Lambda functions"
      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Principal = { Service = "lambda.amazonaws.com" }
            Action = "sts:AssumeRole"
          }
        ]
      })
      attached_policies = ["lambda-execution"]
      max_session_duration = 3600
    }
  }
}
```

## 🔄 Workspace Management

Each account gets its own Terraform workspace:

```bash
# List workspaces
terraform workspace list

# Switch to dev workspace
terraform workspace select dev

# Create new workspace for new account
terraform workspace new staging
```

## 📊 Deployment Examples

```bash
# Deploy IAM resources to development
./scripts/deploy-to-account.sh dev

# Plan changes for production  
./scripts/deploy-to-account.sh prod --plan-only

# Deploy with custom variables
./scripts/deploy-to-account.sh qa --var-file=configs/qa-custom.tfvars

# Import existing policy
terraform import module.iam_management.aws_iam_policy.existing_policy arn:aws:iam::ACCOUNT:policy/ExistingPolicy
```

## 🔍 Troubleshooting

### Common Issues

**Role Assumption Failed**
```bash
# Check role exists and trust policy
aws sts assume-role --role-arn arn:aws:iam::ACCOUNT:role/ROLE --role-session-name test
```

**Backend Access Denied**
```bash
# Verify backend bucket permissions
aws s3 ls s3://terraform-state-ACCOUNT-REGION/
```

**Workspace Issues**
```bash
# Reset workspace state
terraform workspace select default
terraform workspace delete problematic-workspace
```

## 📈 Advanced Usage

### Custom Policy Templates
Create reusable policy templates in `modules/iam-management/policies/`

### Multi-Region Deployment
Configure different regions per account in `accounts.yaml`

### Custom Backends
Modify backend configurations in `backends/` directory

### Automated CI/CD
Use `deploy-to-account.sh` in CI/CD pipelines with `--auto-approve`

---

## 🎯 Next Steps

1. **Configure accounts**: Update `configs/accounts.yaml`
2. **Test connectivity**: Run `./scripts/assume-role.sh dev --test`
3. **Initialize backends**: Run `./scripts/setup-workspace.sh --init-all`
4. **Deploy to dev**: Run `./scripts/deploy-to-account.sh dev`
5. **Import existing resources**: Run `./scripts/import-existing-resources.sh dev`

This setup provides enterprise-grade multi-account Terraform management with full automation and security best practices.