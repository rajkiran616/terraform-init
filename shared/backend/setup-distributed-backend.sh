#!/bin/bash

# Setup Distributed Backend Infrastructure
# This script creates state management resources in each target account

set -e

# Default configuration
PROJECT_NAME="my-company"
AWS_REGION="us-east-1"

# Function to display usage
usage() {
    echo "Usage: $0 -e ENVIRONMENT -r ROLE_ARN -x EXTERNAL_ID -a ACCOUNT_NAME [-p PROJECT_NAME] [-g REGION]"
    echo ""
    echo "Options:"
    echo "  -e ENVIRONMENT    Environment name (dev, staging, prod)"
    echo "  -r ROLE_ARN      ARN of the cross-account role"
    echo "  -x EXTERNAL_ID   External ID for assume role"
    echo "  -a ACCOUNT_NAME  Account name for tagging"
    echo "  -p PROJECT_NAME  Project name (default: my-company)"
    echo "  -g REGION        AWS region (default: us-east-1)"
    echo "  -h               Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 -e dev -r arn:aws:iam::123456789012:role/TerraformCrossAccountRole -x my-external-id -a development"
}

# Parse command line arguments
while getopts "e:r:x:a:p:g:h" opt; do
    case $opt in
        e) ENVIRONMENT="$OPTARG" ;;
        r) ROLE_ARN="$OPTARG" ;;
        x) EXTERNAL_ID="$OPTARG" ;;
        a) ACCOUNT_NAME="$OPTARG" ;;
        p) PROJECT_NAME="$OPTARG" ;;
        g) AWS_REGION="$OPTARG" ;;
        h) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done

# Validate required parameters
if [[ -z "$ENVIRONMENT" || -z "$ROLE_ARN" || -z "$EXTERNAL_ID" || -z "$ACCOUNT_NAME" ]]; then
    echo "Error: Missing required parameters"
    usage
    exit 1
fi

echo "========================================="
echo "Setting up distributed backend for:"
echo "Environment: $ENVIRONMENT"
echo "Account: $ACCOUNT_NAME"
echo "Role ARN: $ROLE_ARN"
echo "Project: $PROJECT_NAME"
echo "Region: $AWS_REGION"
echo "========================================="

# Verify we can assume the role
echo "Testing role assumption..."
ASSUME_ROLE_OUTPUT=$(aws sts assume-role \
    --role-arn "$ROLE_ARN" \
    --role-session-name "backend-setup-test" \
    --external-id "$EXTERNAL_ID" \
    --output json)

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to assume role $ROLE_ARN"
    exit 1
fi

echo "✓ Role assumption successful"

# Create temporary terraform.tfvars for this setup
cat > "backend-${ENVIRONMENT}.tfvars" << EOF
environment      = "$ENVIRONMENT"
aws_region       = "$AWS_REGION"
assume_role_arn  = "$ROLE_ARN"
external_id      = "$EXTERNAL_ID"
project_name     = "$PROJECT_NAME"
account_name     = "$ACCOUNT_NAME"
EOF

echo "Created temporary variables file: backend-${ENVIRONMENT}.tfvars"

# Initialize and apply the backend setup
echo "Initializing Terraform for backend setup..."
terraform init -input=false

echo "Planning backend infrastructure..."
terraform plan -var-file="backend-${ENVIRONMENT}.tfvars" -out="backend-${ENVIRONMENT}.tfplan"

echo ""
echo "About to create the following resources in $ACCOUNT_NAME account:"
echo "- S3 bucket: ${PROJECT_NAME}-${ENVIRONMENT}-terraform-state"
echo "- DynamoDB table: ${PROJECT_NAME}-${ENVIRONMENT}-terraform-locks"
echo "- KMS key for encryption"
echo ""

read -p "Do you want to proceed? (yes/no): " confirm
if [[ $confirm != "yes" ]]; then
    echo "Setup cancelled"
    rm -f "backend-${ENVIRONMENT}.tfvars" "backend-${ENVIRONMENT}.tfplan"
    exit 0
fi

echo "Applying backend infrastructure..."
terraform apply -input=false "backend-${ENVIRONMENT}.tfplan"

# Get the outputs
BUCKET_NAME=$(terraform output -raw state_bucket_name)
DYNAMODB_TABLE=$(terraform output -raw dynamodb_table_name)

echo ""
echo "✅ Backend setup complete!"
echo ""
echo "State bucket: $BUCKET_NAME"
echo "Lock table: $DYNAMODB_TABLE"

# Create backend configuration file for this environment
BACKEND_CONFIG_DIR="../../environments/${ENVIRONMENT}"
mkdir -p "$BACKEND_CONFIG_DIR"

cat > "${BACKEND_CONFIG_DIR}/backend-distributed.hcl" << EOF
# Distributed backend configuration for ${ENVIRONMENT} environment
# Resources are located in the ${ACCOUNT_NAME} account

bucket         = "$BUCKET_NAME"
key            = "terraform.tfstate"
region         = "$AWS_REGION"
dynamodb_table = "$DYNAMODB_TABLE"
encrypt        = true

# Use the same cross-account role for backend access
assume_role {
  role_arn     = "$ROLE_ARN"
  session_name = "terraform-${ENVIRONMENT}"
  external_id  = "$EXTERNAL_ID"
}
EOF

echo "✅ Created backend configuration: ${BACKEND_CONFIG_DIR}/backend-distributed.hcl"

# Clean up temporary files
rm -f "backend-${ENVIRONMENT}.tfvars" "backend-${ENVIRONMENT}.tfplan"

echo ""
echo "🎉 Setup complete for $ENVIRONMENT environment!"
echo ""
echo "Next steps:"
echo "1. Copy your environment configuration to use distributed backend:"
echo "   cd ${BACKEND_CONFIG_DIR}"
echo "   terraform init -backend-config=backend-distributed.hcl -migrate-state"
echo ""
echo "2. Verify the setup:"
echo "   terraform plan"
echo ""
echo "The state for this environment is now stored securely in its own account."