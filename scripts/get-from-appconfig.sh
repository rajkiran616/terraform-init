#!/bin/bash

# Retrieve Environment Configurations from AWS AppConfig
# Usage: ./scripts/get-from-appconfig.sh [environment]
# Example: ./scripts/get-from-appconfig.sh dev

set -e

ENVIRONMENT=${1:-""}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# AppConfig Configuration
APP_NAME="terraform-iam-config"

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

# Function to show usage
show_usage() {
    echo "Usage: $0 <environment>"
    echo ""
    echo "Arguments:"
    echo "  environment    Environment to retrieve (dev, qa, prod)"
    echo ""
    echo "Examples:"
    echo "  $0 dev         # Retrieve dev configuration"
    echo "  $0 qa          # Retrieve qa configuration"
    echo "  $0 prod        # Retrieve prod configuration"
    echo ""
    echo "Prerequisites:"
    echo "  - AWS CLI installed and configured"
    echo "  - Configurations uploaded to AppConfig"
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

# Function to get AppConfig configuration
get_configuration() {
    local env_name=$1
    
    log "Retrieving configuration for environment: $env_name"
    
    # Get application ID
    APP_ID=$(aws appconfig list-applications --query "Items[?Name=='$APP_NAME'].Id" --output text 2>/dev/null || echo "")
    if [ -z "$APP_ID" ]; then
        error "AppConfig application '$APP_NAME' not found. Please upload configurations first."
    fi
    
    # Get environment ID
    ENV_ID=$(aws appconfig list-environments --application-id "$APP_ID" \
        --query "Items[?Name=='$env_name'].Id" --output text 2>/dev/null || echo "")
    if [ -z "$ENV_ID" ]; then
        error "AppConfig environment '$env_name' not found. Please upload configurations first."
    fi
    
    # Get configuration profile ID
    PROFILE_ID=$(aws appconfig list-configuration-profiles --application-id "$APP_ID" \
        --query "Items[?Name=='$env_name-config'].Id" --output text 2>/dev/null || echo "")
    if [ -z "$PROFILE_ID" ]; then
        error "Configuration profile '$env_name-config' not found. Please upload configurations first."
    fi
    
    # Get the latest deployed configuration
    log "Retrieving deployed configuration..."
    
    # Create a temporary file for the configuration
    TEMP_FILE=$(mktemp)
    
    # Retrieve configuration using get-configuration
    aws appconfig get-configuration \
        --application "$APP_ID" \
        --environment "$ENV_ID" \
        --configuration "$PROFILE_ID" \
        --client-id "terraform-$(date +%s)" \
        "$TEMP_FILE" > /dev/null
    
    if [ ! -s "$TEMP_FILE" ]; then
        rm -f "$TEMP_FILE"
        error "No configuration content found for environment '$env_name'. Check if deployment is complete."
    fi
    
    success "Retrieved configuration for '$env_name'"
    
    log "Configuration content:"
    echo "----------------------------------------"
    if command -v jq &> /dev/null; then
        jq . "$TEMP_FILE"
    else
        cat "$TEMP_FILE"
    fi
    echo "----------------------------------------"
    
    # Save to local file for comparison
    local output_file="$PROJECT_DIR/retrieved-$env_name.json"
    cp "$TEMP_FILE" "$output_file"
    success "Configuration saved to: $output_file"
    
    # Clean up
    rm -f "$TEMP_FILE"
}

# Function to list all configurations
list_all_configurations() {
    log "Listing all available configurations..."
    
    # Get application ID
    APP_ID=$(aws appconfig list-applications --query "Items[?Name=='$APP_NAME'].Id" --output text 2>/dev/null || echo "")
    if [ -z "$APP_ID" ]; then
        error "AppConfig application '$APP_NAME' not found."
    fi
    
    success "Application ID: $APP_ID"
    
    # List environments
    log "Available environments:"
    aws appconfig list-environments --application-id "$APP_ID" \
        --query "Items[*].[Name,Id]" --output table
    
    # List configuration profiles
    log "Available configuration profiles:"
    aws appconfig list-configuration-profiles --application-id "$APP_ID" \
        --query "Items[*].[Name,Id,Type]" --output table
}

# Main execution
main() {
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        show_usage
        exit 0
    fi
    
    if [ "$1" = "--list" ] || [ "$1" = "-l" ]; then
        check_prerequisites
        list_all_configurations
        exit 0
    fi
    
    if [ -z "$ENVIRONMENT" ]; then
        error "Environment is required. Use --help for usage information."
    fi
    
    case $ENVIRONMENT in
        "dev"|"qa"|"prod")
            log "Starting AppConfig retrieval for environment: $ENVIRONMENT"
            check_prerequisites
            get_configuration "$ENVIRONMENT"
            success "AppConfig retrieval completed successfully!"
            ;;
        *)
            error "Invalid environment: $ENVIRONMENT. Valid options: dev, qa, prod"
            ;;
    esac
}

# Run main function with all arguments
main "$@"
