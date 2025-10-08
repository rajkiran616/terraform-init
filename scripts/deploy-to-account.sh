#!/bin/bash

# Deploy to Account Script
# Orchestrates role assumption, workspace management, and Terraform deployment

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
    echo "  --plan-only      Only run terraform plan"
    echo "  --auto-approve   Skip confirmation for apply"
    echo "  --init-only      Only initialize backend and workspace"
    echo "  --destroy        Destroy infrastructure"
    echo "  --var-file=FILE  Use custom variables file"
    echo "  --help           Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 dev                           # Deploy to dev account"
    echo "  $0 prod --plan-only              # Plan changes for prod"
    echo "  $0 qa --var-file=custom.tfvars   # Deploy with custom variables"
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
PLAN_ONLY=false
AUTO_APPROVE=false
INIT_ONLY=false
DESTROY=false
VAR_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --plan-only)
            PLAN_ONLY=true
            shift
            ;;
        --auto-approve)
            AUTO_APPROVE=true
            shift
            ;;
        --init-only)
            INIT_ONLY=true
            shift
            ;;
        --destroy)
            DESTROY=true
            shift
            ;;
        --var-file=*)
            VAR_FILE="${1#*=}"
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

# Set variables file if not specified
if [[ -z "$VAR_FILE" ]]; then
    VAR_FILE="$PROJECT_ROOT/configs/${ACCOUNT}.tfvars"
fi

# Validate files exist
if [[ ! -f "$VAR_FILE" ]]; then
    error "Variables file not found: $VAR_FILE"
fi

BACKEND_FILE="$PROJECT_ROOT/backends/${ACCOUNT}-backend.hcl"
if [[ ! -f "$BACKEND_FILE" ]]; then
    error "Backend file not found: $BACKEND_FILE"
fi

log "🚀 Starting deployment to $ACCOUNT account"
log "Variables file: $VAR_FILE"
log "Backend file: $BACKEND_FILE"

# Step 1: Assume role
log "Step 1: Assuming role for $ACCOUNT account"
source <("$SCRIPT_DIR/assume-role.sh" "$ACCOUNT" --export)

if [[ $? -ne 0 ]]; then
    error "Failed to assume role for account: $ACCOUNT"
fi

log "✅ Role assumed successfully"

# Step 2: Initialize backend
log "Step 2: Initializing Terraform backend"
cd "$PROJECT_ROOT"

terraform init -backend-config="$BACKEND_FILE" -reconfigure

if [[ $? -ne 0 ]]; then
    error "Failed to initialize Terraform backend"
fi

log "✅ Backend initialized successfully"

# Step 3: Workspace management
log "Step 3: Managing Terraform workspace"
WORKSPACE_NAME="$ACCOUNT"

# Create or select workspace
if terraform workspace list | grep -q "^[[:space:]]*${WORKSPACE_NAME}[[:space:]]*$"; then
    log "Selecting existing workspace: $WORKSPACE_NAME"
    terraform workspace select "$WORKSPACE_NAME"
else
    log "Creating new workspace: $WORKSPACE_NAME"
    terraform workspace new "$WORKSPACE_NAME"
fi

if [[ $? -ne 0 ]]; then
    error "Failed to manage workspace: $WORKSPACE_NAME"
fi

log "✅ Workspace ready: $WORKSPACE_NAME"

# Exit if init-only
if [[ "$INIT_ONLY" == "true" ]]; then
    log "✅ Initialization complete for $ACCOUNT"
    exit 0
fi

# Step 4: Terraform plan
log "Step 4: Creating Terraform execution plan"
PLAN_FILE="/tmp/terraform-${ACCOUNT}-$(date +%Y%m%d-%H%M%S).tfplan"

if [[ "$DESTROY" == "true" ]]; then
    terraform plan -destroy -var-file="$VAR_FILE" -out="$PLAN_FILE"
else
    terraform plan -var-file="$VAR_FILE" -out="$PLAN_FILE"
fi

if [[ $? -ne 0 ]]; then
    error "Terraform plan failed"
fi

log "✅ Plan created successfully: $PLAN_FILE"

# Exit if plan-only
if [[ "$PLAN_ONLY" == "true" ]]; then
    log "✅ Plan complete for $ACCOUNT"
    log "Plan file saved: $PLAN_FILE"
    exit 0
fi

# Step 5: Confirmation (unless auto-approve or destroy)
if [[ "$AUTO_APPROVE" != "true" ]]; then
    echo ""
    if [[ "$DESTROY" == "true" ]]; then
        warn "⚠️  You are about to DESTROY infrastructure in $ACCOUNT account!"
        warn "This action cannot be undone!"
    else
        log "Ready to apply changes to $ACCOUNT account"
    fi
    
    echo -n "Do you want to proceed? (yes/no): "
    read -r confirmation
    
    if [[ "$confirmation" != "yes" ]]; then
        log "Deployment cancelled by user"
        exit 0
    fi
fi

# Step 6: Apply changes
if [[ "$DESTROY" == "true" ]]; then
    log "Step 6: Destroying infrastructure in $ACCOUNT"
else
    log "Step 6: Applying changes to $ACCOUNT"
fi

terraform apply "$PLAN_FILE"

if [[ $? -ne 0 ]]; then
    if [[ "$DESTROY" == "true" ]]; then
        error "Failed to destroy infrastructure"
    else
        error "Failed to apply changes"
    fi
fi

# Step 7: Show outputs
if [[ "$DESTROY" != "true" ]]; then
    log "Step 7: Deployment outputs"
    terraform output -json | jq .
fi

# Cleanup
rm -f "$PLAN_FILE"

if [[ "$DESTROY" == "true" ]]; then
    log "🎉 Infrastructure destroyed successfully in $ACCOUNT account"
else
    log "🎉 Deployment completed successfully in $ACCOUNT account"
fi

log "Workspace: $WORKSPACE_NAME"
log "Account: $(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo 'unknown')"