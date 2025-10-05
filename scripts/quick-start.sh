#!/bin/bash

# Quick Start Script for Multi-Account Terraform Setup
# This script helps you get started with the Terraform infrastructure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    # Check AWS CLI configuration
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS CLI is not configured properly. Please run 'aws configure'."
        exit 1
    fi
    
    # Check if we're in the right directory
    if [[ ! -f "README.md" ]] || [[ ! -d "modules" ]]; then
        print_error "Please run this script from the terraform-aws-infrastructure root directory."
        exit 1
    fi
    
    print_status "All prerequisites are satisfied."
}

# Gather user input
gather_input() {
    print_header "Configuration Setup"
    
    # Get company/project name
    read -p "Enter your company/project name (lowercase, no spaces): " COMPANY_NAME
    if [[ -z "$COMPANY_NAME" ]]; then
        print_error "Company name cannot be empty."
        exit 1
    fi
    
    # Get AWS region
    read -p "Enter your primary AWS region [us-east-1]: " AWS_REGION
    AWS_REGION=${AWS_REGION:-us-east-1}
    
    # Get owner
    read -p "Enter the infrastructure owner/team name: " OWNER
    OWNER=${OWNER:-infrastructure-team}
    
    # Get cost center
    read -p "Enter cost center [Infrastructure]: " COST_CENTER
    COST_CENTER=${COST_CENTER:-Infrastructure}
    
    # Ask about cross-account roles
    read -p "Do you need to create cross-account roles? (y/N): " CREATE_ROLES
    CREATE_ROLES=${CREATE_ROLES:-n}
    
    print_status "Configuration collected successfully."
}

# Create backend configuration
setup_backend() {
    print_header "Setting Up Terraform Backend"
    
    cd shared/backend
    
    # Create terraform.tfvars for backend
    cat > terraform.tfvars <<EOF
company_name = "$COMPANY_NAME"
aws_region   = "$AWS_REGION"
EOF
    
    print_status "Created backend configuration."
    
    # Initialize and plan
    print_status "Initializing backend..."
    terraform init
    
    print_status "Planning backend resources..."
    terraform plan
    
    read -p "Do you want to create the backend resources (S3 bucket and DynamoDB table)? (y/N): " CREATE_BACKEND
    if [[ "$CREATE_BACKEND" =~ ^[Yy]$ ]]; then
        print_status "Creating backend resources..."
        terraform apply -auto-approve
        
        # Get the outputs
        BUCKET_NAME=$(terraform output -raw s3_bucket_name)
        DYNAMO_TABLE=$(terraform output -raw dynamodb_table_name)
        
        print_status "Backend created successfully!"
        print_status "S3 Bucket: $BUCKET_NAME"
        print_status "DynamoDB Table: $DYNAMO_TABLE"
    else
        print_warning "Backend creation skipped. You'll need to create it manually."
        BUCKET_NAME="terraform-state-${COMPANY_NAME}-XXXXXXXX"
        DYNAMO_TABLE="terraform-state-lock-${COMPANY_NAME}"
    fi
    
    cd ../..
}

# Create backend configurations for environments
create_backend_configs() {
    print_header "Creating Backend Configuration Files"
    
    mkdir -p backend_configs
    
    # Create backend configs for different environments
    for env in root dev staging prod multi-account; do
        cat > backend_configs/${env}.hcl <<EOF
bucket         = "$BUCKET_NAME"
key           = "${env}/terraform.tfstate"
region        = "$AWS_REGION"
dynamodb_table = "$DYNAMO_TABLE"
encrypt       = true
EOF
        print_status "Created backend config for $env environment."
    done
}

# Create main terraform.tfvars
create_main_config() {
    print_header "Creating Main Configuration"
    
    cd environments/multi-account
    
    cat > terraform.tfvars <<EOF
# Project Configuration
project_name = "$COMPANY_NAME"
owner        = "$OWNER"
cost_center  = "$COST_CENTER"
aws_region   = "$AWS_REGION"

# Backend Configuration
terraform_state_bucket = "$BUCKET_NAME"
terraform_lock_table   = "$DYNAMO_TABLE"

# Cross-Account Setup
create_cross_account_roles = $(if [[ "$CREATE_ROLES" =~ ^[Yy]$ ]]; then echo "true"; else echo "false"; fi)
cross_account_role_name    = "TerraformCrossAccountRole"

# Network Configuration
base_cidr = "10.0.0.0/8"
create_nat_gateway_non_prod = false

# Resource Creation Flags
create_web_tier      = true
create_app_tier      = true
create_database_tier = true
create_bastion       = false
create_alb          = false
create_efs          = false
create_route53_zones = false

# Security Configuration  
web_ingress_cidrs = ["0.0.0.0/0"]
bastion_allowed_cidrs = ["10.0.0.0/8"]
app_port = 8080

# DNS Configuration
private_dns_domain = "internal.local"

# Enable monitoring and logging
enable_vpc_flow_logs = true
EOF
    
    print_status "Created main configuration file."
    cd ../..
}

# Initialize multi-account setup
init_multi_account() {
    print_header "Initializing Multi-Account Setup"
    
    cd environments/multi-account
    
    # Initialize with backend
    print_status "Initializing Terraform..."
    terraform init -backend-config="../../backend_configs/multi-account.hcl"
    
    print_status "Planning infrastructure..."
    terraform plan
    
    print_warning "Review the plan above carefully before applying."
    read -p "Do you want to apply this configuration? (y/N): " APPLY_CONFIG
    if [[ "$APPLY_CONFIG" =~ ^[Yy]$ ]]; then
        print_status "Applying configuration..."
        terraform apply
        print_status "Multi-account infrastructure setup complete!"
    else
        print_warning "Configuration not applied. You can run 'terraform apply' later."
    fi
    
    cd ../..
}

# Create helpful scripts
create_scripts() {
    print_header "Creating Utility Scripts"
    
    # Script to check account access
    cat > scripts/check-account-access.sh <<'EOF'
#!/bin/bash
# Check if Terraform can access all discovered accounts

echo "Checking cross-account access..."
cd environments/multi-account

# Get account list from Terraform output
terraform output -json discovered_accounts | jq -r 'keys[]' | while read account_id; do
    account_name=$(terraform output -json discovered_accounts | jq -r ".\"$account_id\".name")
    echo "Testing access to account: $account_name ($account_id)"
    
    aws sts assume-role \
        --role-arn "arn:aws:iam::$account_id:role/TerraformCrossAccountRole" \
        --role-session-name "terraform-test" \
        --query 'Credentials.AccessKeyId' \
        --output text > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo "✅ Access to $account_name successful"
    else
        echo "❌ Access to $account_name failed"
    fi
done
EOF
    chmod +x scripts/check-account-access.sh
    
    # Script to switch between environments
    cat > scripts/switch-environment.sh <<'EOF'
#!/bin/bash
# Switch between different environments

if [ -z "$1" ]; then
    echo "Usage: $0 <environment>"
    echo "Available environments: root, dev, staging, prod, multi-account"
    exit 1
fi

ENV=$1
CONFIG_FILE="../../backend_configs/${ENV}.hcl"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Environment $ENV not found!"
    exit 1
fi

cd "environments/$ENV" 2>/dev/null || {
    echo "Environment directory not found: environments/$ENV"
    exit 1
}

echo "Switching to $ENV environment..."
terraform init -backend-config="$CONFIG_FILE"
echo "Environment switched to $ENV. You can now run terraform commands."
EOF
    chmod +x scripts/switch-environment.sh
    
    print_status "Created utility scripts."
}

# Main execution
main() {
    print_header "Multi-Account Terraform Setup"
    print_status "This script will help you set up Terraform for multi-account AWS infrastructure management."
    
    check_prerequisites
    gather_input
    setup_backend
    create_backend_configs
    create_main_config
    create_scripts
    
    print_header "Setup Complete!"
    print_status "Your Terraform multi-account setup is ready."
    print_status ""
    print_status "Next steps:"
    print_status "1. Review the configuration files created"
    print_status "2. Initialize the multi-account setup:"
    print_status "   cd environments/multi-account"
    print_status "   terraform init -backend-config=\"../../backend_configs/multi-account.hcl\""
    print_status "   terraform plan"
    print_status "   terraform apply"
    print_status ""
    print_status "3. Use utility scripts:"
    print_status "   ./scripts/check-account-access.sh  # Check cross-account access"
    print_status "   ./scripts/switch-environment.sh dev  # Switch to dev environment"
    print_status ""
    print_status "For more information, see the README.md file."
    
    if [[ "$CREATE_ROLES" =~ ^[Yy]$ ]]; then
        init_multi_account
    fi
}

# Run the main function
main "$@"