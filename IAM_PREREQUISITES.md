# IAM Prerequisites for Multi-Account Terraform

This guide details the exact IAM permissions required for the multi-account Terraform setup.

## Overview of Required Permissions

```
Management Account (where you run Terraform):
├── Your User/Role: Permissions to assume cross-account roles
├── Backend Setup: Permissions to create S3/DynamoDB in target accounts
└── State Access: Permissions to read/write state via assumed roles

Target Accounts (dev, staging, prod):
├── Cross-Account Role: Role that management account can assume
├── IAM Permissions: Create/manage IAM policies and roles
├── Backend Permissions: Access to S3 bucket and DynamoDB table
└── Resource Permissions: Deploy your actual infrastructure
```

---

## Phase 1: Management Account Permissions

### Your User/Role Needs These Permissions

**Minimum required policy for your user in the management account:**

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
        "arn:aws:iam::DEV-ACCOUNT-ID:role/TerraformCrossAccountRole",
        "arn:aws:iam::STAGING-ACCOUNT-ID:role/TerraformCrossAccountRole",
        "arn:aws:iam::PROD-ACCOUNT-ID:role/TerraformCrossAccountRole"
      ]
    },
    {
      "Sid": "ManagementAccountAccess",
      "Effect": "Allow",
      "Action": [
        "sts:GetCallerIdentity",
        "sts:GetSessionToken"
      ],
      "Resource": "*"
    }
  ]
}
```

### AWS CLI Command to Create This Policy

```bash
# Create the policy document
cat > management-account-terraform-policy.json << 'EOF'
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
      ]
    },
    {
      "Sid": "ManagementAccountAccess",
      "Effect": "Allow",
      "Action": [
        "sts:GetCallerIdentity",
        "sts:GetSessionToken"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Create the policy
aws iam create-policy \
  --policy-name TerraformMultiAccountAccess \
  --policy-document file://management-account-terraform-policy.json \
  --description "Allows assuming cross-account roles for Terraform"

# Attach to your user (replace with your username)
aws iam attach-user-policy \
  --user-name your-username \
  --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/TerraformMultiAccountAccess
```

---

## Phase 2: Target Account Cross-Account Roles

### Trust Policy (Who Can Assume the Role)

Each target account needs this trust policy:

```json
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
```

### Permission Policies (What the Role Can Do)

#### Option 1: Full IAM Access (Easier, Less Secure)
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:*",
        "s3:*",
        "dynamodb:*",
        "kms:*"
      ],
      "Resource": "*"
    }
  ]
}
```

#### Option 2: Least Privilege (Recommended for Production)
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "IAMManagement",
      "Effect": "Allow",
      "Action": [
        "iam:CreatePolicy",
        "iam:CreatePolicyVersion",
        "iam:CreateRole",
        "iam:CreateInstanceProfile",
        "iam:GetPolicy",
        "iam:GetPolicyVersion",
        "iam:GetRole",
        "iam:GetRolePolicy",
        "iam:ListAttachedRolePolicies",
        "iam:ListInstanceProfilesForRole",
        "iam:ListPolicyVersions",
        "iam:ListRolePolicies",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:DeleteRole",
        "iam:DeletePolicy",
        "iam:DeletePolicyVersion",
        "iam:PassRole",
        "iam:TagRole",
        "iam:UntagRole",
        "iam:TagPolicy",
        "iam:UntagPolicy",
        "iam:UpdateRole",
        "iam:UpdateRoleDescription",
        "iam:AddRoleToInstanceProfile",
        "iam:RemoveRoleFromInstanceProfile",
        "iam:DeleteInstanceProfile"
      ],
      "Resource": "*"
    },
    {
      "Sid": "S3BackendAccess",
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:GetBucketLocation",
        "s3:GetBucketVersioning",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:PutBucketVersioning",
        "s3:PutBucketEncryption",
        "s3:GetBucketEncryption",
        "s3:PutBucketPublicAccessBlock",
        "s3:GetBucketPublicAccessBlock",
        "s3:PutBucketPolicy",
        "s3:GetBucketPolicy",
        "s3:DeleteBucketPolicy"
      ],
      "Resource": [
        "arn:aws:s3:::*terraform-state*",
        "arn:aws:s3:::*terraform-state*/*"
      ]
    },
    {
      "Sid": "DynamoDBBackendAccess",
      "Effect": "Allow",
      "Action": [
        "dynamodb:CreateTable",
        "dynamodb:DeleteTable",
        "dynamodb:DescribeTable",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem",
        "dynamodb:UpdateItem",
        "dynamodb:UpdateTable",
        "dynamodb:TagResource",
        "dynamodb:UntagResource",
        "dynamodb:ListTagsOfResource",
        "dynamodb:UpdateTimeToLive",
        "dynamodb:DescribeTimeToLive",
        "dynamodb:UpdateContinuousBackups",
        "dynamodb:DescribeContinuousBackups"
      ],
      "Resource": [
        "arn:aws:dynamodb:*:*:table/*terraform*"
      ]
    },
    {
      "Sid": "KMSAccess",
      "Effect": "Allow",
      "Action": [
        "kms:CreateKey",
        "kms:CreateAlias",
        "kms:DeleteAlias",
        "kms:DescribeKey",
        "kms:GetKeyPolicy",
        "kms:GetKeyRotationStatus",
        "kms:ListAliases",
        "kms:ListKeys",
        "kms:PutKeyPolicy",
        "kms:TagResource",
        "kms:UntagResource",
        "kms:UpdateKeyDescription",
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ],
      "Resource": "*"
    }
  ]
}
```

### Commands to Create the Cross-Account Role

Run these commands **in each target account**:

```bash
# Set variables
MANAGEMENT_ACCOUNT_ID="123456789012"  # Your management account ID
EXTERNAL_ID="your-unique-external-id-2024"
ROLE_NAME="TerraformCrossAccountRole"
ENVIRONMENT="dev"  # Change for each account

# Create trust policy
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

# Create permission policy (choose Option 1 OR Option 2 above)
cat > terraform-permissions.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:*",
        "s3:*", 
        "dynamodb:*",
        "kms:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Create the role
aws iam create-role \
  --role-name ${ROLE_NAME} \
  --assume-role-policy-document file://trust-policy.json \
  --description "Cross-account role for Terraform deployments"

# Create and attach custom policy
aws iam create-policy \
  --policy-name TerraformCrossAccountPolicy \
  --policy-document file://terraform-permissions.json \
  --description "Permissions for Terraform cross-account operations"

# Attach the policy to the role
aws iam attach-role-policy \
  --role-name ${ROLE_NAME} \
  --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/TerraformCrossAccountPolicy

# Clean up
rm trust-policy.json terraform-permissions.json

# Get the role ARN for your records
aws iam get-role --role-name ${ROLE_NAME} --query Role.Arn --output text
```

---

## Phase 3: Testing Permissions

### Test Cross-Account Access
```bash
# From management account, test assuming each role
aws sts assume-role \
  --role-arn arn:aws:iam::DEV-ACCOUNT-ID:role/TerraformCrossAccountRole \
  --role-session-name permission-test \
  --external-id your-unique-external-id-2024

# If successful, test IAM permissions with the assumed role
export AWS_ACCESS_KEY_ID=AKIA...  # From assume-role output
export AWS_SECRET_ACCESS_KEY=...  # From assume-role output  
export AWS_SESSION_TOKEN=...     # From assume-role output

# Test IAM access
aws iam list-roles --max-items 1

# Test S3 access
aws s3 ls

# Test DynamoDB access  
aws dynamodb list-tables
```

### Verification Script
```bash
#!/bin/bash
# verify-permissions.sh

ACCOUNTS=("DEV-ACCOUNT-ID" "STAGING-ACCOUNT-ID" "PROD-ACCOUNT-ID")
EXTERNAL_ID="your-unique-external-id-2024"

for ACCOUNT in "${ACCOUNTS[@]}"; do
    echo "Testing access to account: $ACCOUNT"
    
    RESULT=$(aws sts assume-role \
        --role-arn arn:aws:iam::${ACCOUNT}:role/TerraformCrossAccountRole \
        --role-session-name permission-test \
        --external-id ${EXTERNAL_ID} \
        --output json 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo "✅ Successfully assumed role in account $ACCOUNT"
    else
        echo "❌ Failed to assume role in account $ACCOUNT"
    fi
done
```

---

## Security Considerations

### 1. External ID Best Practices
- Use a **unique, unpredictable** external ID
- Consider using UUIDs: `uuidgen` (macOS) or `python3 -c "import uuid; print(uuid.uuid4())"`
- Store securely and use consistently across all accounts

### 2. Least Privilege Progression
```
Start with: Broad permissions for initial setup
Progress to: Service-specific permissions
End with: Resource-specific permissions with conditions
```

### 3. Regular Permission Audits
```bash
# List all policies attached to the cross-account role
aws iam list-attached-role-policies --role-name TerraformCrossAccountRole

# Review policy versions
aws iam get-policy --policy-arn POLICY_ARN
aws iam get-policy-version --policy-arn POLICY_ARN --version-id v1
```

### 4. Conditional Access (Advanced)
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "iam:*",
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": ["us-east-1", "us-west-2"]
        },
        "DateGreaterThan": {
          "aws:CurrentTime": "2024-01-01T00:00:00Z"
        }
      }
    }
  ]
}
```

---

## Troubleshooting Permission Issues

### Common Error Messages and Solutions

**"User is not authorized to perform: sts:AssumeRole"**
- Check if your management account user has the assume role permission
- Verify the role ARN is correct
- Confirm the external ID matches

**"Cross-account role assumption failed"**
- Verify the trust policy in target account allows your management account
- Check the external ID condition
- Ensure the role exists in the target account

**"Access denied when creating IAM resources"**
- Verify the cross-account role has IAM permissions
- Check if there are any policy boundaries limiting permissions
- Confirm the role has the specific actions needed (CreatePolicy, CreateRole, etc.)

**"S3 bucket operations failed"**
- Ensure the role has S3 permissions for state bucket operations
- Check if bucket policies are blocking access
- Verify KMS permissions for encrypted buckets

### Debug Commands
```bash
# Check what permissions your current credentials have
aws sts get-caller-identity

# Test specific permissions
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT:role/TerraformCrossAccountRole \
  --action-names iam:CreateRole s3:CreateBucket dynamodb:CreateTable

# Check CloudTrail logs for permission denials
aws logs filter-log-events \
  --log-group-name CloudTrail/ManagementEvents \
  --filter-pattern "ERROR Denied"
```

---

## Quick Setup Checklist

- [ ] Management account user has assume role permissions
- [ ] Cross-account roles created in all target accounts  
- [ ] Trust policies allow management account with external ID
- [ ] Roles have IAM, S3, DynamoDB, and KMS permissions
- [ ] External ID is unique and secure
- [ ] Role assumption tested from management account
- [ ] Terraform can successfully assume roles and create resources

This IAM setup provides the foundation for secure, multi-account Terraform operations with proper isolation and least privilege access.