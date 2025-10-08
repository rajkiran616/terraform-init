#!/bin/bash

# Import Existing IAM Resources Script
# Helps import existing IAM policies and roles into Terraform state

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    echo "Usage: $0 <account> [OPTIONS]"
    echo ""
    echo "Arguments:"
    echo "  account     Account name (dev, qa, test, prod)"
    echo ""
    echo "Options:"
    echo "  --list-only      Only list existing resources, don't import"
    echo "  --policy=NAME    Import specific policy"
    echo "  --role=NAME      Import specific role"
    echo "  --help           Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 dev --list-only                    # List existing resources"
    echo "  $0 prod --policy=ExistingPolicy       # Import specific policy"
    echo "  $0 qa --role=ExistingRole             # Import specific role"
}

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Parse arguments
ACCOUNT=""
LIST_ONLY=false
SPECIFIC_POLICY=""
SPECIFIC_ROLE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --list-only)
            LIST_ONLY=true
            shift
            ;;
        --policy=*)
            SPECIFIC_POLICY="${1#*=}"
            shift
            ;;
        --role=*)
            SPECIFIC_ROLE="${1#*=}"
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            if [[ -z "$ACCOUNT" ]]; then
                ACCOUNT="$1"
            else
                error "Unknown option: $1"
            fi
            shift
            ;;
    esac
done

# Validate account
if [[ -z "$ACCOUNT" ]]; then
    error "Account name is required"
fi

log "🔍 Importing existing IAM resources for $ACCOUNT account"

# Step 1: Assume role
log "Step 1: Assuming role for $ACCOUNT account"
source <("$SCRIPT_DIR/assume-role.sh" "$ACCOUNT" --export)

if [[ $? -ne 0 ]]; then
    error "Failed to assume role for account: $ACCOUNT"
fi

# Step 2: Initialize if needed
cd "$PROJECT_ROOT"
BACKEND_FILE="$PROJECT_ROOT/backends/${ACCOUNT}-backend.hcl"

if [[ -f "$BACKEND_FILE" ]]; then
    log "Initializing Terraform backend"
    terraform init -backend-config="$BACKEND_FILE" -reconfigure > /dev/null 2>&1
    
    # Select workspace
    if terraform workspace list | grep -q "^[[:space:]]*${ACCOUNT}[[:space:]]*$"; then
        terraform workspace select "$ACCOUNT" > /dev/null 2>&1
    fi
fi

# Function to list existing policies
list_existing_policies() {
    log "📋 Listing existing IAM policies..."
    aws iam list-policies --scope Local --query 'Policies[].{Name:PolicyName,Arn:Arn,Description:Description}' --output table
}

# Function to list existing roles  
list_existing_roles() {
    log "👥 Listing existing IAM roles..."
    aws iam list-roles --query 'Roles[?!starts_with(RoleName, `AWSServiceRole`)].{Name:RoleName,Arn:Arn,Description:Description}' --output table
}

# Function to import policy
import_policy() {
    local policy_name=$1
    local policy_arn=$2
    
    log "Importing policy: $policy_name"
    
    # Check if resource exists in configuration
    if terraform plan -var-file="configs/${ACCOUNT}.tfvars" | grep -q "module.iam_management.aws_iam_policy.custom\\[\"$policy_name\"\\]"; then
        log "Policy $policy_name found in configuration, importing..."
        terraform import "module.iam_management.aws_iam_policy.custom[\"$policy_name\"]" "$policy_arn"
    else
        warn "Policy $policy_name not found in Terraform configuration"
        warn "Add it to configs/${ACCOUNT}.tfvars first"
    fi
}

# Function to import role
import_role() {
    local role_name=$1
    
    log "Importing role: $role_name"
    
    # Check if resource exists in configuration
    if terraform plan -var-file="configs/${ACCOUNT}.tfvars" | grep -q "module.iam_management.aws_iam_role.custom\\[\"$role_name\"\\]"; then
        log "Role $role_name found in configuration, importing..."
        terraform import "module.iam_management.aws_iam_role.custom[\"$role_name\"]" "$role_name"
    else
        warn "Role $role_name not found in Terraform configuration"
        warn "Add it to configs/${ACCOUNT}.tfvars first"
    fi
}

# Main execution
if [[ "$LIST_ONLY" == "true" ]]; then
    list_existing_policies
    echo ""
    list_existing_roles
    exit 0
fi

if [[ -n "$SPECIFIC_POLICY" ]]; then
    # Get policy ARN
    POLICY_ARN=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='$SPECIFIC_POLICY'].Arn" --output text)
    if [[ -n "$POLICY_ARN" && "$POLICY_ARN" != "None" ]]; then
        import_policy "$SPECIFIC_POLICY" "$POLICY_ARN"
    else
        error "Policy not found: $SPECIFIC_POLICY"
    fi
fi

if [[ -n "$SPECIFIC_ROLE" ]]; then
    # Check if role exists
    if aws iam get-role --role-name "$SPECIFIC_ROLE" > /dev/null 2>&1; then
        import_role "$SPECIFIC_ROLE"
    else
        error "Role not found: $SPECIFIC_ROLE"
    fi
fi

if [[ -z "$SPECIFIC_POLICY" && -z "$SPECIFIC_ROLE" ]]; then
    log "Interactive import mode"
    log ""
    log "Instructions for importing existing resources:"
    log "1. First, add the existing resource to your configs/${ACCOUNT}.tfvars file"
    log "2. Then run: terraform import module.iam_management.aws_iam_policy.custom[\"policy-name\"] policy-arn"
    log "3. Or run: terraform import module.iam_management.aws_iam_role.custom[\"role-name\"] role-name"
    log ""
    
    list_existing_policies
    echo ""
    list_existing_roles
    
    log ""
    log "Example import commands:"
    log "  terraform import 'module.iam_management.aws_iam_policy.custom[\"my-policy\"]' arn:aws:iam::ACCOUNT:policy/MyPolicy"
    log "  terraform import 'module.iam_management.aws_iam_role.custom[\"my-role\"]' MyRole"
fi

log "✅ Import process complete for $ACCOUNT account"