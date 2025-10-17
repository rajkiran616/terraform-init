#!/bin/bash

# Upload Environment Configurations to AWS AppConfig
# Usage: ./scripts/upload-to-appconfig.sh [environment]
# Example: ./scripts/upload-to-appconfig.sh dev

set -e

ENVIRONMENT=${1:-"all"}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# AppConfig Configuration
APP_NAME="terraform-iam-config"
DEPLOYMENT_STRATEGY_ID="AppConfig.Linear20PercentEvery6Minutes"
DESCRIPTION="Terraform IAM configuration for environment-specific deployments"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

# Function to check if AWS CLI is installed and configured
check_prerequisites() {
    log "Checking prerequisites..."
    
    if ! command -v aws &> /dev/null; then
        error "AWS CLI is not installed. Please install it first."
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS CLI is not configured or credentials are invalid."
    fi
    
    success "Prerequisites check passed"
}

# Function to create AppConfig application if it doesn't exist
create_application() {
    log "Checking if AppConfig application exists..."
    
    APP_ID=$(aws appconfig list-applications --query "Items[?Name=='$APP_NAME'].Id" --output text 2>/dev/null || echo "")
    
    if [ -z "$APP_ID" ]; then
        log "Creating AppConfig application: $APP_NAME"
        APP_ID=$(aws appconfig create-application \
            --name "$APP_NAME" \
            --description "$DESCRIPTION" \
            --tags Key=ManagedBy,Value=terraform Key=Purpose,Value=iam-configuration \
            --query 'Id' --output text)
        success "Created application with ID: $APP_ID"
    else
        success "Application already exists with ID: $APP_ID"
    fi
}

# Function to create environment in AppConfig
create_appconfig_environment() {
    local env_name=$1
    
    log "Checking if AppConfig environment '$env_name' exists..."
    
    ENV_ID=$(aws appconfig list-environments --application-id "$APP_ID" \
        --query "Items[?Name=='$env_name'].Id" --output text 2>/dev/null || echo "")
    
    if [ -z "$ENV_ID" ]; then
        log "Creating AppConfig environment: $env_name"
        ENV_ID=$(aws appconfig create-environment \
            --application-id "$APP_ID" \
            --name "$env_name" \
            --description "Environment configuration for $env_name" \
            --tags Key=Environment,Value="$env_name" Key=ManagedBy,Value=terraform \
            --query 'Id' --output text)
        success "Created environment '$env_name' with ID: $ENV_ID"
    else
        success "Environment '$env_name' already exists with ID: $ENV_ID"
    fi
}

# Function to create configuration profile
create_configuration_profile() {
    local env_name=$1
    
    log "Checking if configuration profile exists for '$env_name'..."
    
    PROFILE_ID=$(aws appconfig list-configuration-profiles --application-id "$APP_ID" \
        --query "Items[?Name=='$env_name-config'].Id" --output text 2>/dev/null || echo "")
    
    if [ -z "$PROFILE_ID" ]; then
        log "Creating configuration profile for '$env_name'..."
        PROFILE_ID=$(aws appconfig create-configuration-profile \
            --application-id "$APP_ID" \
            --name "$env_name-config" \
            --description "IAM configuration profile for $env_name environment" \
            --location-uri "hosted" \
            --type "AWS.AppConfig.FeatureFlags" \
            --tags Key=Environment,Value="$env_name" Key=ManagedBy,Value=terraform \
            --query 'Id' --output text)
        success "Created configuration profile '$env_name-config' with ID: $PROFILE_ID"
    else
        success "Configuration profile '$env_name-config' already exists with ID: $PROFILE_ID"
    fi
}

# Function to upload configuration version
upload_configuration() {
    local env_name=$1
    local config_file="$PROJECT_DIR/config/$env_name.json"
    
    if [ ! -f "$config_file" ]; then
        error "Configuration file not found: $config_file"
    fi
    
    log "Validating JSON configuration for '$env_name'..."
    if ! jq empty "$config_file" 2>/dev/null; then
        error "Invalid JSON in configuration file: $config_file"
    fi
    
    log "Uploading configuration for '$env_name'..."
    
    # Create hosted configuration version
    VERSION_NUMBER=$(aws appconfig create-hosted-configuration-version \
        --application-id "$APP_ID" \
        --configuration-profile-id "$PROFILE_ID" \
        --description "IAM configuration for $env_name environment - $(date)" \
        --content-type "application/json" \
        --content fileb://"$config_file" \
        --query 'VersionNumber' --output text)
    
    success "Uploaded configuration version $VERSION_NUMBER for '$env_name'"
    
    # Start deployment
    log "Starting deployment for '$env_name'..."
    DEPLOYMENT_NUMBER=$(aws appconfig start-deployment \
        --application-id "$APP_ID" \
        --environment-id "$ENV_ID" \
        --deployment-strategy-id "$DEPLOYMENT_STRATEGY_ID" \
        --configuration-profile-id "$PROFILE_ID" \
        --configuration-version "$VERSION_NUMBER" \
        --description "Deployment of $env_name configuration - $(date)" \
        --tags Key=Environment,Value="$env_name" Key=DeployedBy,Value="$(whoami)" \
        --query 'DeploymentNumber' --output text)
    
    success "Started deployment #$DEPLOYMENT_NUMBER for '$env_name'"
}

# Function to process a single environment
process_environment() {
    local env_name=$1
    
    log "Processing environment: $env_name"
    
    create_appconfig_environment "$env_name"
    create_configuration_profile "$env_name"
    upload_configuration "$env_name"
    
    success "Completed processing for environment: $env_name"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [environment]"
    echo ""
    echo "Arguments:"
    echo "  environment    Environment to upload (dev, qa, prod, all)"
    echo "                 Default: all"
    echo ""
    echo "Examples:"
    echo "  $0 dev         # Upload only dev configuration"
    echo "  $0 qa          # Upload only qa configuration"
    echo "  $0 prod        # Upload only prod configuration"
    echo "  $0 all         # Upload all configurations (default)"
    echo ""
    echo "Prerequisites:"
    echo "  - AWS CLI installed and configured"
    echo "  - Appropriate IAM permissions for AppConfig"
    echo "  - Valid JSON configuration files in config/ directory"
}

# Main execution
main() {
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        show_usage
        exit 0
    fi
    
    log "Starting AWS AppConfig upload process..."
    log "Target: $ENVIRONMENT"
    
    check_prerequisites
    create_application
    
    case $ENVIRONMENT in
        "dev")
            process_environment "dev"
            ;;
        "qa")
            process_environment "qa"
            ;;
        "prod")
            process_environment "prod"
            ;;
        "all")
            process_environment "dev"
            process_environment "qa"
            process_environment "prod"
            ;;
        *)
            error "Invalid environment: $ENVIRONMENT. Valid options: dev, qa, prod, all"
            ;;
    esac
    
    success "AWS AppConfig upload process completed successfully!"
    
    log "Next steps:"
    echo "1. Update your Terraform configuration to use AppConfig data sources"
    echo "2. Run 'terraform init' to initialize the updated configuration"
    echo "3. Run 'terraform apply -var=\"environment=<env>\"' to deploy"
}

# Run main function with all arguments
main "$@"