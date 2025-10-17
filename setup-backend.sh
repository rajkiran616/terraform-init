#!/bin/bash

# Script to set up Terraform backend resources (S3 bucket + DynamoDB table)
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Default values
DEFAULT_BUCKET_NAME="terraform-state-$(aws sts get-caller-identity --query Account --output text)-$(date +%Y%m%d)"
DEFAULT_TABLE_NAME="terraform-state-locks"
DEFAULT_REGION="us-east-1"

# Get user input
echo -e "${BLUE}=== Terraform Backend Setup ===${NC}"
echo

read -p "Enter S3 bucket name [${DEFAULT_BUCKET_NAME}]: " BUCKET_NAME
BUCKET_NAME=${BUCKET_NAME:-$DEFAULT_BUCKET_NAME}

read -p "Enter DynamoDB table name [${DEFAULT_TABLE_NAME}]: " TABLE_NAME
TABLE_NAME=${TABLE_NAME:-$DEFAULT_TABLE_NAME}

read -p "Enter AWS region [${DEFAULT_REGION}]: " REGION
REGION=${REGION:-$DEFAULT_REGION}

echo
print_info "Will create:"
print_info "  S3 Bucket: ${BUCKET_NAME}"
print_info "  DynamoDB Table: ${TABLE_NAME}"
print_info "  Region: ${REGION}"
echo

read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Cancelled."
    exit 0
fi

# Check if AWS CLI is configured
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    print_error "AWS CLI not configured or invalid credentials"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
print_info "Using AWS Account: ${ACCOUNT_ID}"

# Create S3 bucket
print_info "Creating S3 bucket: ${BUCKET_NAME}"

if aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
    print_warning "S3 bucket ${BUCKET_NAME} already exists"
else
    if [ "${REGION}" = "us-east-1" ]; then
        aws s3api create-bucket \
            --bucket "${BUCKET_NAME}" \
            --region "${REGION}"
    else
        aws s3api create-bucket \
            --bucket "${BUCKET_NAME}" \
            --region "${REGION}" \
            --create-bucket-configuration LocationConstraint="${REGION}"
    fi
    print_success "S3 bucket created"
fi

# Enable versioning
print_info "Enabling S3 bucket versioning"
aws s3api put-bucket-versioning \
    --bucket "${BUCKET_NAME}" \
    --versioning-configuration Status=Enabled

# Enable encryption
print_info "Enabling S3 bucket encryption"
aws s3api put-bucket-encryption \
    --bucket "${BUCKET_NAME}" \
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
print_info "Blocking public access to S3 bucket"
aws s3api put-public-access-block \
    --bucket "${BUCKET_NAME}" \
    --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

print_success "S3 bucket configured"

# Create DynamoDB table
print_info "Creating DynamoDB table: ${TABLE_NAME}"

if aws dynamodb describe-table --table-name "${TABLE_NAME}" --region "${REGION}" >/dev/null 2>&1; then
    print_warning "DynamoDB table ${TABLE_NAME} already exists"
else
    aws dynamodb create-table \
        --table-name "${TABLE_NAME}" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --region "${REGION}"
    
    print_info "Waiting for DynamoDB table to be active..."
    aws dynamodb wait table-exists --table-name "${TABLE_NAME}" --region "${REGION}"
    print_success "DynamoDB table created"
fi

# Update backend configuration in main.tf
print_info "Updating backend configuration in main.tf"
sed -i.bak "s/your-terraform-state-bucket/${BUCKET_NAME}/g" main.tf
sed -i.bak "s/us-east-1/${REGION}/g" main.tf
sed -i.bak "s/terraform-state-locks/${TABLE_NAME}/g" main.tf

# Clean up backup file
rm -f main.tf.bak

# Update terraform.tfvars.example
print_info "Updating terraform.tfvars.example"
cat >> terraform.tfvars.example << EOF

# Backend configuration (already set in main.tf, but useful for reference)
# state_bucket_name    = "${BUCKET_NAME}"
# state_dynamodb_table = "${TABLE_NAME}"
# state_region         = "${REGION}"
EOF

print_success "Backend setup complete!"
echo
print_info "Backend configuration:"
print_info "  S3 Bucket: ${BUCKET_NAME}"
print_info "  DynamoDB Table: ${TABLE_NAME}"
print_info "  Region: ${REGION}"
echo
print_info "Next steps:"
echo "  1. Run 'terraform init' to initialize the backend"
echo "  2. Continue with your normal Terraform workflow"
echo
print_warning "Note: main.tf has been updated with your backend configuration"