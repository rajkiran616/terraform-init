# Setting Up Cross-Account IAM Roles

Before you can use the multi-account Terraform setup, you need to create IAM roles in each target account that allow the management account to assume them.

## Step 1: Create Cross-Account Roles in Each Target Account

### For Development Account:
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
          "sts:ExternalId": "your-external-id-here"
        }
      }
    }
  ]
}
```

### AWS CLI Commands to Create Roles:

```bash
# Replace these variables with your actual values
MANAGEMENT_ACCOUNT_ID="123456789012"
EXTERNAL_ID="your-unique-external-id"
ROLE_NAME="TerraformCrossAccountRole"

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

# Create the role in each account
aws iam create-role \
  --role-name ${ROLE_NAME} \
  --assume-role-policy-document file://trust-policy.json \
  --description "Cross-account role for Terraform deployments"

# Attach necessary policies (adjust as needed)
aws iam attach-role-policy \
  --role-name ${ROLE_NAME} \
  --policy-arn arn:aws:iam::aws:policy/IAMFullAccess

# For more restrictive access, create custom policies instead
aws iam attach-role-policy \
  --role-name ${ROLE_NAME} \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess
```

## Step 2: Note the Role ARNs

After creating roles in each account, note down the ARNs:

- **Dev Account**: `arn:aws:iam::DEV-ACCOUNT-ID:role/TerraformCrossAccountRole`
- **Staging Account**: `arn:aws:iam::STAGING-ACCOUNT-ID:role/TerraformCrossAccountRole`
- **Prod Account**: `arn:aws:iam::PROD-ACCOUNT-ID:role/TerraformCrossAccountRole`

## Step 3: Create a Custom Policy for Terraform (Recommended)

Instead of using broad policies like PowerUserAccess, create a custom policy with only the permissions needed:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:CreatePolicy",
        "iam:CreateRole",
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
        "iam:PassRole",
        "iam:TagRole",
        "iam:UntagRole",
        "iam:UpdateRole",
        "iam:UpdateRoleDescription"
      ],
      "Resource": "*"
    }
  ]
}
```

## Step 4: Verify the Setup

Test that you can assume the role from your management account:

```bash
aws sts assume-role \
  --role-arn arn:aws:iam::TARGET-ACCOUNT-ID:role/TerraformCrossAccountRole \
  --role-session-name test-session \
  --external-id your-external-id-here
```

## Security Best Practices

1. **Use External ID**: Always use an external ID for additional security
2. **Least Privilege**: Only grant the minimum permissions required
3. **Session Names**: Use descriptive session names for auditing
4. **MFA**: Consider requiring MFA for production account roles
5. **Time Limits**: Set maximum session duration appropriately
6. **Regular Audits**: Regularly review and audit cross-account access

## Example Role Creation with MFA (Optional for Production)

For production accounts, you might want to require MFA:

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
          "sts:ExternalId": "your-external-id-here"
        },
        "Bool": {
          "aws:MultiFactorAuthPresent": "true"
        }
      }
    }
  ]
}
```