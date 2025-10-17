#!/bin/bash

# Setup S3 bucket for Terraform state with native locking
# Usage: ./scripts/setup-state-bucket.sh <bucket-name> [region]

set -e

BUCKET_NAME=${1:-""}
REGION=${2:-"us-east-1"}

if [ -z "$BUCKET_NAME" ]; then
    echo "Usage: $0 <bucket-name> [region]"
    echo "Example: $0 my-terraform-state-bucket us-east-1"
    exit 1
fi

echo "Setting up S3 bucket for Terraform state: $BUCKET_NAME"
echo "Region: $REGION"

# Create the bucket
echo "Creating S3 bucket..."
if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION"
else
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" \
        --create-bucket-configuration LocationConstraint="$REGION"
fi

# Enable versioning (required for S3 native state locking)
echo "Enabling versioning..."
aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled

# Enable server-side encryption
echo "Enabling server-side encryption..."
aws s3api put-bucket-encryption --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }
        ]
    }'

# Block public access
echo "Blocking public access..."
aws s3api put-public-access-block --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Add bucket policy for additional security
echo "Adding bucket policy..."
aws s3api put-bucket-policy --bucket "$BUCKET_NAME" --policy "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [
        {
            \"Sid\": \"DenyInsecureConnections\",
            \"Effect\": \"Deny\",
            \"Principal\": \"*\",
            \"Action\": \"s3:*\",
            \"Resource\": [
                \"arn:aws:s3:::$BUCKET_NAME\",
                \"arn:aws:s3:::$BUCKET_NAME/*\"
            ],
            \"Condition\": {
                \"Bool\": {
                    \"aws:SecureTransport\": \"false\"
                }
            }
        }
    ]
}"

echo "✅ S3 bucket setup complete!"
echo ""
echo "Bucket configuration:"
echo "  - Name: $BUCKET_NAME"
echo "  - Region: $REGION"
echo "  - Versioning: Enabled (required for state locking)"
echo "  - Encryption: AES256"
echo "  - Public access: Blocked"
echo "  - Secure transport: Required"
echo ""
echo "Update your backend configuration:"
echo "  bucket = \"$BUCKET_NAME\""
echo "  region = \"$REGION\""
echo ""
echo "You can now run: terraform init"