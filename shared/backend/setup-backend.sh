#!/bin/bash

# Script to set up Terraform backend infrastructure
# Run this script first to create the S3 bucket and DynamoDB table for state management

set -e

# Configuration
STATE_BUCKET_NAME="my-company-terraform-state"
DYNAMODB_TABLE_NAME="terraform-state-locks"
AWS_REGION="us-east-1"

echo "Setting up Terraform backend infrastructure..."
echo "Bucket: $STATE_BUCKET_NAME"
echo "DynamoDB Table: $DYNAMODB_TABLE_NAME"
echo "Region: $AWS_REGION"
echo ""

# Check if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "Error: AWS CLI not configured or no valid credentials found"
    exit 1
fi

echo "Current AWS identity:"
aws sts get-caller-identity

echo ""
echo "Creating S3 bucket for Terraform state..."

# Create S3 bucket
if aws s3 ls "s3://$STATE_BUCKET_NAME" 2>&1 | grep -q 'NoSuchBucket'; then
    aws s3 mb "s3://$STATE_BUCKET_NAME" --region "$AWS_REGION"
    echo "✓ S3 bucket created: $STATE_BUCKET_NAME"
else
    echo "✓ S3 bucket already exists: $STATE_BUCKET_NAME"
fi

# Enable versioning on the bucket
aws s3api put-bucket-versioning \
    --bucket "$STATE_BUCKET_NAME" \
    --versioning-configuration Status=Enabled

echo "✓ S3 bucket versioning enabled"

# Enable encryption on the bucket
aws s3api put-bucket-encryption \
    --bucket "$STATE_BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                },
                "BucketKeyEnabled": true
            }
        ]
    }'

echo "✓ S3 bucket encryption enabled"

# Block public access
aws s3api put-public-access-block \
    --bucket "$STATE_BUCKET_NAME" \
    --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "✓ S3 bucket public access blocked"

echo ""
echo "Creating DynamoDB table for state locking..."

# Check if DynamoDB table exists
if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE_NAME" --region "$AWS_REGION" > /dev/null 2>&1; then
    echo "✓ DynamoDB table already exists: $DYNAMODB_TABLE_NAME"
else
    # Create DynamoDB table
    aws dynamodb create-table \
        --table-name "$DYNAMODB_TABLE_NAME" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$AWS_REGION" \
        --tags Key=Name,Value="Terraform State Locks" Key=Environment,Value=management Key=Purpose,Value=terraform-state-locking

    echo "✓ DynamoDB table created: $DYNAMODB_TABLE_NAME"
    
    echo "Waiting for table to become active..."
    aws dynamodb wait table-exists --table-name "$DYNAMODB_TABLE_NAME" --region "$AWS_REGION"
    echo "✓ DynamoDB table is active"
fi

echo ""
echo "Backend setup complete!"
echo ""
echo "Next steps:"
echo "1. Update the bucket name in backend.hcl files if different from: $STATE_BUCKET_NAME"
echo "2. Update the DynamoDB table name in backend.hcl files if different from: $DYNAMODB_TABLE_NAME"
echo "3. Initialize Terraform in each environment directory with: terraform init -backend-config=backend.hcl"
echo ""
echo "Example:"
echo "  cd environments/dev"
echo "  terraform init -backend-config=backend.hcl"