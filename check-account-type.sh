#!/bin/bash

# Script to verify you're using appropriate account for Terraform operations
# Helps ensure you're not running from root account

set -e

echo "🔍 Checking AWS Account Type..."
echo "================================"

# Get current account info
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
USER_ARN=$(aws sts get-caller-identity --query Arn --output text)

echo "Current Account ID: $ACCOUNT_ID"
echo "Current User/Role:  $USER_ARN"
echo ""

# Check if this is an organization account
ORG_CHECK=$(aws organizations describe-organization --query Organization.Id --output text 2>/dev/null || echo "NOT_IN_ORG")

if [ "$ORG_CHECK" != "NOT_IN_ORG" ]; then
    # This account is part of an organization
    MASTER_ACCOUNT=$(aws organizations describe-organization --query Organization.MasterAccountId --output text 2>/dev/null || echo "UNKNOWN")
    
    if [ "$ACCOUNT_ID" = "$MASTER_ACCOUNT" ]; then
        echo "⚠️  WARNING: You are in the ROOT/MASTER account!"
        echo "🏛️  Account Type: ROOT/MASTER ACCOUNT"
        echo ""
        echo "❌ This is NOT recommended for Terraform operations"
        echo ""
        echo "✅ Recommended Actions:"
        echo "1. Create a dedicated Management/Ops account"
        echo "2. Run Terraform operations from that account"
        echo "3. Keep root account for organization management only"
        echo ""
        echo "📖 See DEDICATED_MANAGEMENT_ACCOUNT_GUIDE.md for details"
        exit 1
    else
        echo "✅ This appears to be a MEMBER account (good!)"
        echo "🏛️  Account Type: ORGANIZATION MEMBER ACCOUNT"
        
        # Try to get account name/details
        ACCOUNT_INFO=$(aws organizations describe-account --account-id $ACCOUNT_ID --query 'Account.[Name,Email]' --output text 2>/dev/null || echo "UNKNOWN UNKNOWN")
        ACCOUNT_NAME=$(echo $ACCOUNT_INFO | cut -d' ' -f1)
        ACCOUNT_EMAIL=$(echo $ACCOUNT_INFO | cut -d' ' -f2)
        
        echo "Account Name:  $ACCOUNT_NAME"
        echo "Account Email: $ACCOUNT_EMAIL"
        echo ""
        
        if [[ $ACCOUNT_NAME == *"management"* ]] || [[ $ACCOUNT_NAME == *"ops"* ]] || [[ $ACCOUNT_NAME == *"terraform"* ]]; then
            echo "✅ Account name suggests this is a management/ops account - Perfect!"
        else
            echo "⚠️  Account name doesn't clearly indicate management/ops purpose"
            echo "💡 Consider using a clearly named management account for Terraform operations"
        fi
    fi
else
    echo "🏛️  Account Type: STANDALONE ACCOUNT (not part of organization)"
    echo ""
    echo "✅ This is acceptable for single-account or simple setups"
    echo "💡 For multi-account organizations, consider AWS Organizations with dedicated management account"
fi

echo ""
echo "🔐 Security Recommendations:"
echo "- Use dedicated management account for Terraform operations"
echo "- Never run Terraform from root account"
echo "- Implement least-privilege cross-account roles"
echo "- Use external IDs for additional security"
echo ""

# Check for existing Terraform state
if [ -f "terraform.tfstate" ] || [ -d ".terraform" ]; then
    echo "📂 Terraform state detected in current directory"
    if [ "$ACCOUNT_ID" = "${MASTER_ACCOUNT:-}" ]; then
        echo "❌ WARNING: Terraform state in root account!"
        echo "🔄 Consider migrating to dedicated management account"
    else
        echo "✅ Terraform state in non-root account (good)"
    fi
else
    echo "📂 No local Terraform state detected"
    echo "✅ Good - using remote state is recommended"
fi

echo ""
echo "🎯 Summary:"
if [ "$ACCOUNT_ID" = "${MASTER_ACCOUNT:-}" ]; then
    echo "❌ CRITICAL: Do not run Terraform from root account"
    echo "   Action required: Set up dedicated management account"
    exit 1
else
    echo "✅ Account type appears appropriate for Terraform operations"
    echo "🚀 You can proceed with the setup"
    exit 0
fi