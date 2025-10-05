#!/bin/bash

# Setup IAM permissions in management account for Terraform multi-account operations
# Run this script in your management account

set -e

# Configuration
POLICY_NAME="TerraformMultiAccountAccess"
EXTERNAL_ID="terraform-multiAccount-$(date +%Y%m%d)-$(openssl rand -hex 4)"

echo "=================================================="
echo "Setting up IAM permissions for Terraform multi-account operations"
echo "Management Account IAM Setup"
echo "=================================================="

# Get current account info
MANAGEMENT_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
CURRENT_USER=$(aws sts get-caller-identity --query Arn --output text)

echo "Management Account ID: $MANAGEMENT_ACCOUNT_ID"
echo "Current User/Role: $CURRENT_USER"
echo "Generated External ID: $EXTERNAL_ID"
echo ""

# Extract username from ARN
if [[ $CURRENT_USER == *":user/"* ]]; then
    USERNAME=$(echo $CURRENT_USER | cut -d'/' -f2)
    ENTITY_TYPE="user"
    echo "Detected IAM User: $USERNAME"
elif [[ $CURRENT_USER == *":assumed-role/"* ]]; then
    ROLE_NAME=$(echo $CURRENT_USER | cut -d'/' -f2)
    ENTITY_TYPE="role"
    echo "Detected IAM Role: $ROLE_NAME"
    echo "⚠️  Note: You're using a role. Make sure it has permission to attach policies."
else
    echo "❌ Unable to determine user type from ARN: $CURRENT_USER"
    exit 1
fi

# Create policy document
echo "Creating IAM policy document..."
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

# Check if policy already exists
EXISTING_POLICY_ARN="arn:aws:iam::${MANAGEMENT_ACCOUNT_ID}:policy/${POLICY_NAME}"
if aws iam get-policy --policy-arn "$EXISTING_POLICY_ARN" > /dev/null 2>&1; then
    echo "✅ Policy $POLICY_NAME already exists"
    POLICY_ARN=$EXISTING_POLICY_ARN
else
    # Create the policy
    echo "Creating IAM policy: $POLICY_NAME"
    CREATE_RESULT=$(aws iam create-policy \
        --policy-name "$POLICY_NAME" \
        --policy-document file://management-account-terraform-policy.json \
        --description "Allows assuming cross-account roles for Terraform multi-account operations")
    
    POLICY_ARN=$(echo $CREATE_RESULT | python3 -c "import sys, json; print(json.load(sys.stdin)['Policy']['Arn'])")
    echo "✅ Created policy: $POLICY_ARN"
fi

# Attach policy based on entity type
if [ "$ENTITY_TYPE" == "user" ]; then
    # Check if policy is already attached to user
    if aws iam list-attached-user-policies --user-name "$USERNAME" --query "AttachedPolicies[?PolicyArn=='$POLICY_ARN'].PolicyArn" --output text | grep -q "$POLICY_ARN"; then
        echo "✅ Policy already attached to user: $USERNAME"
    else
        echo "Attaching policy to user: $USERNAME"
        aws iam attach-user-policy \
            --user-name "$USERNAME" \
            --policy-arn "$POLICY_ARN"
        echo "✅ Policy attached to user: $USERNAME"
    fi
elif [ "$ENTITY_TYPE" == "role" ]; then
    # Check if policy is already attached to role
    if aws iam list-attached-role-policies --role-name "$ROLE_NAME" --query "AttachedPolicies[?PolicyArn=='$POLICY_ARN'].PolicyArn" --output text | grep -q "$POLICY_ARN"; then
        echo "✅ Policy already attached to role: $ROLE_NAME"
    else
        echo "Attaching policy to role: $ROLE_NAME"
        aws iam attach-role-policy \
            --role-name "$ROLE_NAME" \
            --policy-arn "$POLICY_ARN"
        echo "✅ Policy attached to role: $ROLE_NAME"
    fi
fi

# Clean up temporary file
rm -f management-account-terraform-policy.json

echo ""
echo "=================================================="
echo "✅ Management Account IAM Setup Complete!"
echo "=================================================="
echo ""
echo "Important Information:"
echo "📋 Management Account ID: $MANAGEMENT_ACCOUNT_ID"
echo "🔑 Generated External ID: $EXTERNAL_ID"
echo "📝 Policy ARN: $POLICY_ARN"
echo ""
echo "⚠️  SAVE THIS EXTERNAL ID - You'll need it for all target accounts:"
echo "   External ID: $EXTERNAL_ID"
echo ""
echo "Next Steps:"
echo "1. Save the External ID above in a secure location"
echo "2. Set up cross-account roles in each target account using the External ID"
echo "3. Use this External ID in all terraform.tfvars files"
echo ""
echo "Example for target accounts:"
echo "   export MANAGEMENT_ACCOUNT_ID=\"$MANAGEMENT_ACCOUNT_ID\""
echo "   export EXTERNAL_ID=\"$EXTERNAL_ID\""
echo ""
echo "Verification:"
echo "Run this command to test your permissions:"
echo "   aws sts get-caller-identity"