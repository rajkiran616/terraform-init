# Dedicated Management Account Architecture

## Why Not Use Root Account?

Using a dedicated **Management/Ops Account** instead of the root account provides:

✅ **Security Isolation**: Root account remains pristine for billing/organizational tasks only  
✅ **Least Privilege**: Management account has only Terraform-related permissions  
✅ **Better Governance**: Clear separation of concerns  
✅ **Audit Trail**: Dedicated account for all infrastructure operations  
✅ **Team Access**: Easier to manage team access to ops account vs root  

## Recommended Account Structure

```
Organization Root Account (Hands-off)
├── Security/Audit Account (Logging, monitoring)
├── Management/Ops Account (Terraform operations) ← You run Terraform here
├── Shared Services Account (DNS, networking) 
├── Dev Account (Development workloads)
├── Staging Account (Staging workloads)
└── Prod Account (Production workloads)
```

## Updated Architecture

### What Changes:

**Before (Root Account Model):**
```
Root Account → Assumes roles in → [Dev, Staging, Prod]
❌ Root account has Terraform state and operations
```

**After (Dedicated Management Account):**
```
Management Account → Assumes roles in → [Dev, Staging, Prod]
✅ Root account stays clean for org-level tasks only
✅ Dedicated ops account for all Terraform operations
```

### Account Responsibilities:

| Account Type | Responsibilities | Terraform Usage |
|--------------|-----------------|----------------|
| **Root Account** | Billing, organization management, account creation | ❌ No Terraform |
| **Management Account** | Terraform operations, state storage, CI/CD | ✅ Primary Terraform account |
| **Security Account** | Logging, monitoring, compliance | ❌ Managed by Management Account |
| **Target Accounts** | Application workloads, resources | ❌ Managed by Management Account |

## Implementation Guide

### Phase 1: Create Management Account

If you don't have a dedicated management account yet:

```bash
# From Root Account (one-time setup)
aws organizations create-account \
  --email management@yourcompany.com \
  --account-name "Management-Ops"

# Note the account ID from the response
MANAGEMENT_ACCOUNT_ID="111122223333"
```

### Phase 2: Set Up Cross-Account Access

#### Root Account → Management Account Access (One-time)

Create a role in the **Management Account** that the **Root Account** can assume (for initial setup only):

```bash
# In Management Account, create role for root account initial access
cat > root-to-management-trust.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::ROOT-ACCOUNT-ID:root"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create the role (run in Management Account)
aws iam create-role \
  --role-name RootAccountInitialAccess \
  --assume-role-policy-document file://root-to-management-trust.json \
  --description "Temporary role for root account to set up management account"

# Attach admin policy (temporary)
aws iam attach-role-policy \
  --role-name RootAccountInitialAccess \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

#### Management Account → Target Accounts Access

Set up the same cross-account roles as before, but now the **Management Account** assumes roles in target accounts:

```bash
# In each target account (Dev, Staging, Prod)
# Update the trust policy to allow Management Account instead of Root
cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::MANAGEMENT-ACCOUNT-ID:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "your-unique-external-id"
        }
      }
    }
  ]
}
EOF

# Create cross-account role in each target account
aws iam create-role \
  --role-name TerraformCrossAccountRole \
  --assume-role-policy-document file://trust-policy.json \
  --description "Cross-account role for Terraform deployments from Management Account"
```

### Phase 3: Update Terraform Configuration

#### Update Provider Configuration

Change the provider configuration to reflect the new architecture:

```hcl
# In shared/provider-configs/providers.tf
provider "aws" {
  region = var.aws_region
  
  # Now assuming role from Management Account (not root)
  assume_role {
    role_arn     = var.assume_role_arn
    session_name = "terraform-${var.environment}"
    external_id  = var.external_id
  }

  default_tags {
    tags = {
      Environment     = var.environment
      ManagedBy      = "Terraform"
      Project        = var.project_name
      Owner          = var.owner
      CostCenter     = var.cost_center
      ManagementAcct = "true"  # Tag to indicate managed from dedicated account
    }
  }
}
```

#### Update Backend Setup Script

Update the distributed backend setup to use Management Account:

```bash
# In shared/backend/setup-distributed-backend.sh
# Add comment at the top:
# This script should be run FROM the Management Account
# It will create backend resources IN each target account
```

## Security Model

### Management Account IAM Structure

```
Management Account:
├── TerraformOperators Group
│   ├── User: ops-user-1
│   ├── User: ops-user-2
│   └── Policy: AssumeTargetAccountRoles
├── CI/CD Role
│   └── Policy: AssumeTargetAccountRoles + S3/DynamoDB for state
└── Backend Resources (if using centralized state)
    ├── S3: management-terraform-state
    └── DynamoDB: management-terraform-locks
```

### Recommended Management Account IAM Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AssumeTargetAccountRoles",
      "Effect": "Allow",
      "Action": [
        "sts:AssumeRole"
      ],
      "Resource": [
        "arn:aws:iam::*:role/TerraformCrossAccountRole"
      ],
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": ["us-east-1", "us-west-2"]
        }
      }
    },
    {
      "Sid": "ManagementAccountOperations",
      "Effect": "Allow",
      "Action": [
        "sts:GetCallerIdentity",
        "sts:GetSessionToken",
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": [
        "arn:aws:s3:::*terraform-state*",
        "arn:aws:s3:::*terraform-state*/*",
        "arn:aws:dynamodb:*:*:table/*terraform-locks*"
      ]
    }
  ]
}
```

## Updated Terraform Usage

### Running Terraform

All Terraform operations now happen from the **Management Account**:

```bash
# 1. Assume role into Management Account (if needed)
aws sts assume-role \
  --role-arn arn:aws:iam::MANAGEMENT-ACCOUNT-ID:role/TerraformOperators \
  --role-session-name terraform-session

# 2. Set credentials from assume-role output
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...

# 3. Run Terraform as normal
cd environments/dev
terraform init -backend-config=backend-distributed.hcl
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

### Updated terraform.tfvars

```hcl
environment     = "dev"
aws_region      = "us-east-1"

# Role in target account that Management Account will assume
assume_role_arn = "arn:aws:iam::DEV-ACCOUNT-ID:role/TerraformCrossAccountRole"
external_id     = "your-unique-external-id-2024"

# Management account info (for tagging/tracking)
project_name = "my-company"
owner       = "management-account-ops"
cost_center = "engineering"
```

## Migration from Root Account

If you're currently using the root account, here's how to migrate:

### Step 1: Create Management Account
```bash
# Create new management account (from root)
aws organizations create-account \
  --email terraform-ops@yourcompany.com \
  --account-name "Terraform-Management"
```

### Step 2: Move State to Management Account
```bash
# Option 1: Re-run backend setup from Management Account
# Option 2: Move existing state files to Management Account S3
```

### Step 3: Update Cross-Account Trust Policies
```bash
# In each target account, update trust policies to trust Management Account
# Instead of Root Account
```

### Step 4: Decommission Root Account Access
```bash
# Remove Terraform-related policies from root account
# Keep only organization management permissions
```

## Benefits of This Architecture

### 1. **Security**
- Root account remains pristine
- Dedicated account for ops activities
- Clear audit trail

### 2. **Scalability** 
- Easy to add more target accounts
- Team can have access to Management Account without root access
- CI/CD systems can use Management Account

### 3. **Compliance**
- Satisfies security frameworks requiring dedicated ops accounts
- Clear separation of billing vs operational concerns
- Better governance and controls

### 4. **Operational Excellence**
- Dedicated account for all Terraform state and operations
- No risk of accidentally affecting organization-level settings
- Easier troubleshooting and monitoring

This architecture provides enterprise-grade security while maintaining operational efficiency and follows AWS best practices for multi-account organizations.