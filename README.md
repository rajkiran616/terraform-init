# Multi-Account AWS Infrastructure with Terraform

This repository manages AWS infrastructure across multiple accounts using Terraform with **distributed state management** for enterprise-grade security and isolation.

## 🚀 Quick Start

### Prerequisites
- ✅ Terraform installed (version 1.0+)
- ✅ AWS CLI configured
- 🔄 Multiple AWS accounts (dev, staging, prod)
- 🔄 Access to create cross-account roles
- 🔄 **IAM permissions set up** - See [IAM_PREREQUISITES.md](IAM_PREREQUISITES.md) for detailed requirements

### 30-Second Overview
```bash
# 0. Verify you're in the right account (not root!)
./check-account-type.sh

# 1. Install Terraform (if needed)
brew install hashicorp/tap/terraform

# 2. Set up cross-account roles in target accounts
# 3. Deploy distributed backend to each account
# 4. Deploy your infrastructure
```

---

## 📋 Step-by-Step Setup Instructions

### Phase 1: Install Prerequisites

#### Step 1.1: Install Terraform
```bash
# Install Terraform via Homebrew
brew install hashicorp/tap/terraform

# Verify installation
terraform version
```

#### Step 1.2: Verify AWS CLI
```bash
# Check AWS CLI installation
aws --version

# Verify current AWS credentials
aws sts get-caller-identity
```

### Phase 2: Set Up Cross-Account Roles

> **🏛️ Important**: Use a **dedicated Management/Ops Account** instead of your root account. See [DEDICATED_MANAGEMENT_ACCOUNT_GUIDE.md](DEDICATED_MANAGEMENT_ACCOUNT_GUIDE.md) for detailed architecture guidance.

#### Step 2.1: Get Your Management Account ID
```bash
# Note down your current (dedicated management/ops) account ID
# DO NOT use your root/master account for this
MANAGEMENT_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Management Account ID: $MANAGEMENT_ACCOUNT_ID"

# Verify you're in the correct account
aws organizations describe-account --account-id $MANAGEMENT_ACCOUNT_ID || echo "Not an org account - that's fine for dedicated mgmt account"
```

#### Step 2.2: Create Cross-Account Roles in Each Target Account

For **each target account** (dev, staging, prod), switch to that account and run:

```bash
# Set variables (update these for each account)
export MANAGEMENT_ACCOUNT_ID="123456789012"  # Your management account ID
export EXTERNAL_ID="my-unique-external-id-2024"  # Choose a unique external ID
export ROLE_NAME="TerraformCrossAccountRole"

# Create trust policy file
cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${MANAGEMENT_ACCOUNT_ID}:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "${EXTERNAL_ID}"
        }
      }
    }
  ]
}
EOF

# Create the role
aws iam create-role \
  --role-name ${ROLE_NAME} \
  --assume-role-policy-document file://trust-policy.json \
  --description "Cross-account role for Terraform deployments"

# Attach necessary policies
aws iam attach-role-policy \
  --role-name ${ROLE_NAME} \
  --policy-arn arn:aws:iam::aws:policy/IAMFullAccess

# Clean up
rm trust-policy.json

# Note the role ARN for later use
aws iam get-role --role-name ${ROLE_NAME} --query Role.Arn --output text
```

#### Step 2.3: Test Cross-Account Access

From your management account, test assuming each role:

```bash
# Test dev account role
aws sts assume-role \
  --role-arn arn:aws:iam::DEV-ACCOUNT-ID:role/TerraformCrossAccountRole \
  --role-session-name test-session \
  --external-id my-unique-external-id-2024

# If successful, you'll see temporary credentials
```

### Phase 3: Set Up Distributed Backend Infrastructure

#### Step 3.1: Set Up Backend in Each Account

For each target account, run the automated setup script:

```bash
cd shared/backend

# Set up backend in development account
./setup-distributed-backend.sh \
  -e dev \
  -r arn:aws:iam::DEV-ACCOUNT-ID:role/TerraformCrossAccountRole \
  -x my-unique-external-id-2024 \
  -a development \
  -p my-company

# Set up backend in staging account  
./setup-distributed-backend.sh \
  -e staging \
  -r arn:aws:iam::STAGING-ACCOUNT-ID:role/TerraformCrossAccountRole \
  -x my-unique-external-id-2024 \
  -a staging \
  -p my-company

# Set up backend in production account
./setup-distributed-backend.sh \
  -e prod \
  -r arn:aws:iam::PROD-ACCOUNT-ID:role/TerraformCrossAccountRole \
  -x my-unique-external-id-2024 \
  -a production \
  -p my-company
```

**What this creates in each account:**
- S3 bucket: `my-company-{env}-terraform-state`
- DynamoDB table: `my-company-{env}-terraform-locks`  
- KMS key for encryption
- Backend configuration file: `environments/{env}/backend-distributed.hcl`

### Phase 4: Configure and Deploy Infrastructure

#### Step 4.1: Configure Development Environment

```bash
cd ../../environments/dev

# Create terraform.tfvars from example
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your actual values
vim terraform.tfvars
```

Update `terraform.tfvars` with:
```hcl
environment     = "dev"
aws_region      = "us-east-1"

# Update with your actual dev account details
assume_role_arn = "arn:aws:iam::DEV-ACCOUNT-ID:role/TerraformCrossAccountRole"
external_id     = "my-unique-external-id-2024"

# Project configuration
project_name = "my-company"
owner       = "infrastructure-team"
cost_center = "engineering"
```

#### Step 4.2: Use Distributed Backend Configuration

```bash
# Use the distributed backend version
cp main-distributed.tf main.tf

# Initialize Terraform with distributed backend
terraform init -backend-config=backend-distributed.hcl

# Plan your infrastructure
terraform plan -var-file="terraform.tfvars"

# Apply (deploy) your infrastructure
terraform apply -var-file="terraform.tfvars"
```

#### Step 4.3: Set Up Other Environments

```bash
# Copy dev configuration to staging
cp -r ../dev ../staging
cd ../staging

# Update terraform.tfvars for staging
vim terraform.tfvars
# Change environment = "staging"
# Update assume_role_arn to staging account

# Initialize and deploy staging
terraform init -backend-config=backend-distributed.hcl
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"

# Repeat for production
cp -r ../dev ../prod
cd ../prod
# Update terraform.tfvars for production
# Deploy production environment
```

---

## 🏗️ Architecture Overview

### Directory Structure
```
terraform-multi-account/
├── README.md                          # This comprehensive guide
├── DISTRIBUTED_BACKEND_GUIDE.md       # Detailed backend guide
├── modules/                           # Reusable Terraform modules
│   └── iam-policies/                 # IAM policies module
├── environments/                      # Environment-specific configs
│   ├── dev/                          # Development account
│   │   ├── main-distributed.tf      # Distributed backend version
│   │   ├── backend-distributed.hcl  # Backend configuration
│   │   ├── terraform.tfvars.example # Example variables
│   │   └── variables.tf             # Variable definitions
│   ├── staging/                     # Staging account
│   └── prod/                        # Production account
└── shared/                           # Shared configurations
    ├── backend/                      # Backend setup
    │   ├── distributed-backend.tf   # Distributed backend resources
    │   └── setup-distributed-backend.sh # Automated setup script
    └── provider-configs/            # Provider configurations
```

### Distributed State Architecture
```
Dev Account:     [S3: dev-terraform-state] + [DynamoDB: dev-locks]
Staging Account: [S3: staging-terraform-state] + [DynamoDB: staging-locks]  
Prod Account:    [S3: prod-terraform-state] + [DynamoDB: prod-locks]

✅ Complete isolation between environments
✅ Reduced blast radius
✅ Enhanced security and compliance
```

---

## 🔧 Daily Operations

### Deploy Changes to an Environment
```bash
cd environments/dev
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

### Add New IAM Policies
Edit `environments/{env}/main.tf` and add to the `policies` map:

```hcl
policies = {
  # Existing policies...
  
  "new-service-policy" = {
    description = "Policy for new service"
    policy_document = {
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = ["service:*"]
          Resource = "*"
        }
      ]
    }
  }
}
```

### View Infrastructure State
```bash
# List all resources
terraform state list

# Show specific resource
terraform state show aws_iam_policy.policy_name

# Refresh state
terraform refresh
```

---

## 🔒 Security Features

- **Cross-Account Isolation**: Each account's state is completely separate
- **KMS Encryption**: State files encrypted with account-specific keys
- **External ID Verification**: Additional security layer for role assumption
- **Least Privilege**: Roles have minimal required permissions
- **Versioning**: Full state history with point-in-time recovery
- **SSL/TLS**: All communications encrypted in transit

---

## 📚 Additional Resources

- **[DEDICATED_MANAGEMENT_ACCOUNT_GUIDE.md](DEDICATED_MANAGEMENT_ACCOUNT_GUIDE.md)** - ⭐ Dedicated management account architecture (recommended)
- **[DISTRIBUTED_BACKEND_GUIDE.md](DISTRIBUTED_BACKEND_GUIDE.md)** - Detailed backend architecture guide
- **[IAM_PREREQUISITES.md](IAM_PREREQUISITES.md)** - Complete IAM permission requirements
- **[shared/provider-configs/setup-cross-account-roles.md](shared/provider-configs/setup-cross-account-roles.md)** - Cross-account role setup guide
- **[SETUP_GUIDE.md](SETUP_GUIDE.md)** - Alternative centralized setup guide

---

## 🆘 Troubleshooting

### Common Issues

**"Access Denied" when assuming role:**
- Verify role ARN is correct
- Check external ID matches
- Ensure role trust policy allows your account

**Backend initialization failed:**
- Verify S3 bucket exists in target account
- Check DynamoDB table exists
- Confirm cross-account role has S3/DynamoDB permissions

**State lock errors:**
```bash
# List locks
aws dynamodb scan --table-name my-company-dev-terraform-locks

# Force unlock (use carefully)
terraform force-unlock LOCK_ID
```

### Verification Commands
```bash
# Test role assumption
aws sts assume-role \
  --role-arn arn:aws:iam::ACCOUNT:role/TerraformCrossAccountRole \
  --role-session-name test \
  --external-id your-external-id

# Check backend resources
aws s3 ls s3://my-company-dev-terraform-state/ --profile dev
aws dynamodb describe-table --table-name my-company-dev-terraform-locks --profile dev
```

---

## ✅ Success Checklist

- [ ] Terraform installed and verified
- [ ] AWS CLI configured with management account
- [ ] Cross-account roles created in all target accounts
- [ ] Role assumption tested from management account
- [ ] Distributed backend deployed to all accounts
- [ ] Dev environment configured and deployed
- [ ] Staging environment configured and deployed  
- [ ] Production environment configured and deployed
- [ ] Team documentation updated with account-specific details

🎉 **Congratulations!** You now have enterprise-grade multi-account Terraform infrastructure with distributed state management.
