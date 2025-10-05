# Multi-Account Terraform Setup Guide

This guide walks you through setting up and using the multi-account Terraform infrastructure.

## Overview

This setup provides:
- **Multi-account AWS management** using cross-account roles
- **Remote state management** with S3 and DynamoDB
- **Reusable modules** for common infrastructure patterns
- **Environment separation** for dev, staging, and production
- **Centralized IAM policy management**

## Prerequisites

1. ✅ Terraform installed (version 1.0+)
2. ✅ AWS CLI installed and configured
3. 🔄 Multiple AWS accounts (dev, staging, prod)
4. 🔄 Cross-account roles set up
5. 🔄 S3 bucket and DynamoDB table for state management

## Step-by-Step Setup

### Phase 1: Initial Setup (Current Account)

**1. Set up the backend infrastructure** (one-time setup):
```bash
# From the project root
cd shared/backend
./setup-backend.sh
```

This creates:
- S3 bucket for Terraform state
- DynamoDB table for state locking
- Proper security configurations

**2. Test basic Terraform functionality**:
```bash
cd environments/dev

# Create terraform.tfvars from the example
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
# For initial testing, you can use placeholder values

# Test with the simple configuration
terraform init
terraform plan -var-file="terraform.tfvars" test-main.tf
terraform apply -var-file="terraform.tfvars" test-main.tf
```

### Phase 2: Cross-Account Setup

**1. Set up cross-account roles in each target account**:

For each target AWS account (dev, staging, prod), run these commands:

```bash
# Set your variables
export MANAGEMENT_ACCOUNT_ID="123456789012"  # Your current account
export EXTERNAL_ID="your-unique-external-id"
export ROLE_NAME="TerraformCrossAccountRole"

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

# Switch to target account and create role
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
```

**2. Update terraform.tfvars with actual role ARNs**:
```bash
# Edit environments/dev/terraform.tfvars
assume_role_arn = "arn:aws:iam::DEV-ACCOUNT-ID:role/TerraformCrossAccountRole"
external_id     = "your-unique-external-id"
```

**3. Test cross-account access**:
```bash
# Verify you can assume the role
aws sts assume-role \
  --role-arn arn:aws:iam::DEV-ACCOUNT-ID:role/TerraformCrossAccountRole \
  --role-session-name test-session \
  --external-id your-unique-external-id
```

### Phase 3: Full Deployment

**1. Configure remote backend**:
```bash
cd environments/dev

# Update backend.hcl with your bucket name if needed
# Initialize with remote backend
terraform init -backend-config=backend.hcl
```

**2. Switch to the full configuration**:
```bash
# Rename files to use full configuration
mv main.tf main.tf.full
mv test-main.tf main.tf.bak  # Keep test config as backup

# Or create a new main.tf based on the full example
# Use the main.tf configuration for full functionality
```

**3. Deploy to development**:
```bash
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

**4. Set up other environments**:
```bash
# Copy dev configuration to staging and prod
cp -r environments/dev environments/staging
cp -r environments/dev environments/prod

# Update terraform.tfvars in each environment:
# - Change environment name
# - Update assume_role_arn for each account
# - Adjust any environment-specific settings
```

## Usage Examples

### Deploying to an Environment

```bash
cd environments/dev
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

### Adding New IAM Policies

Edit `environments/{env}/main.tf` and add to the `policies` map in the `iam_policies` module:

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

### Managing State

```bash
# View current state
terraform state list

# Import existing resources
terraform import aws_iam_policy.existing_policy arn:aws:iam::123456789012:policy/ExistingPolicy

# Show state file location
terraform state pull
```

## Security Considerations

1. **Least Privilege**: Only grant necessary permissions to cross-account roles
2. **External ID**: Always use external IDs for additional security
3. **MFA**: Consider requiring MFA for production account access
4. **State Security**: Ensure state bucket has proper access controls
5. **Regular Audits**: Review cross-account access regularly

## Troubleshooting

### Common Issues

**1. "Access Denied" when assuming role**:
- Check role ARN is correct
- Verify external ID matches
- Ensure role trust policy allows your account

**2. "Backend initialization failed"**:
- Verify S3 bucket exists and you have access
- Check DynamoDB table exists
- Confirm AWS credentials are configured

**3. "Provider configuration error"**:
- Check assume_role_arn format
- Verify AWS region settings
- Ensure role has necessary permissions

### Verification Commands

```bash
# Check current AWS identity
aws sts get-caller-identity

# Test assume role
aws sts assume-role \
  --role-arn arn:aws:iam::ACCOUNT:role/ROLE \
  --role-session-name test \
  --external-id EXTERNAL_ID

# Check S3 backend
aws s3 ls s3://your-terraform-state-bucket/

# Check DynamoDB locks table
aws dynamodb scan --table-name terraform-state-locks --select COUNT
```

## Next Steps

1. **Automate**: Set up CI/CD pipelines for Terraform deployments
2. **Monitor**: Add CloudTrail logging for infrastructure changes
3. **Scale**: Add more environments and accounts as needed
4. **Enhance**: Add more modules for different AWS services
5. **Document**: Keep this guide updated with your specific configurations

## Support

- Review the `README.md` for project structure details
- Check `shared/provider-configs/setup-cross-account-roles.md` for detailed role setup
- Refer to Terraform AWS provider documentation for advanced configurations