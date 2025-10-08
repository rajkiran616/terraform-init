#!/bin/bash

# Automated Role Assumption Script
# Assumes role in target account and exports temporary credentials

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ACCOUNTS_CONFIG="$PROJECT_ROOT/configs/accounts.yaml"
CREDENTIALS_FILE="/tmp/terraform-aws-credentials-$(whoami)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 <account> [--test|--export|--show]"
    echo ""
    echo "Options:"
    echo "  account     Account name (dev, qa, test, prod)"
    echo "  --test      Test role assumption without setting credentials"
    echo "  --export    Export credentials to environment"
    echo "  --show      Show assumed role information"
    echo "  --clear     Clear cached credentials"
    echo ""
    echo "Examples:"
    echo "  $0 dev --test              # Test dev account access"
    echo "  $0 prod --export           # Export prod credentials"
    echo "  source <($0 qa --export)   # Source credentials into current shell"
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

# Check dependencies
check_dependencies() {
    command -v yq >/dev/null 2>&1 || error "yq is required but not installed. Install with: brew install yq"
    command -v aws >/dev/null 2>&1 || error "AWS CLI is required but not installed"
    command -v jq >/dev/null 2>&1 || error "jq is required but not installed. Install with: brew install jq"
}

# Parse account configuration
get_account_config() {
    local account=$1
    local key=$2
    
    if [[ ! -f "$ACCOUNTS_CONFIG" ]]; then
        error "Account configuration file not found: $ACCOUNTS_CONFIG"
    fi
    
    yq eval ".accounts.$account.$key" "$ACCOUNTS_CONFIG" 2>/dev/null || {
        error "Account '$account' not found in configuration or key '$key' missing"
    }
}

# Validate account exists
validate_account() {
    local account=$1
    
    if [[ -z "$account" ]]; then
        error "Account name is required"
    fi
    
    local account_id=$(get_account_config "$account" "account_id")
    if [[ "$account_id" == "null" || -z "$account_id" ]]; then
        error "Account '$account' not found in configuration"
    fi
}

# Assume role and get temporary credentials
assume_role() {
    local account=$1
    local test_only=${2:-false}
    
    validate_account "$account"
    
    local account_id=$(get_account_config "$account" "account_id")
    local role_name=$(get_account_config "$account" "role_name")
    local session_name=$(yq eval ".organization.role_session_name" "$ACCOUNTS_CONFIG")
    local external_id=$(yq eval ".organization.external_id" "$ACCOUNTS_CONFIG")
    
    local role_arn="arn:aws:iam::${account_id}:role/${role_name}"
    
    log "Assuming role: $role_arn"
    log "Session name: $session_name"
    
    # Build assume role command
    local assume_cmd="aws sts assume-role --role-arn $role_arn --role-session-name $session_name"
    
    # Add external ID if configured
    if [[ "$external_id" != "null" && -n "$external_id" ]]; then
        assume_cmd="$assume_cmd --external-id $external_id"
        log "Using external ID: $external_id"
    fi
    
    # Execute assume role
    local credentials
    if ! credentials=$($assume_cmd --output json 2>/dev/null); then
        error "Failed to assume role $role_arn. Check your permissions and role configuration."
    fi
    
    # Parse credentials
    local access_key=$(echo "$credentials" | jq -r '.Credentials.AccessKeyId')
    local secret_key=$(echo "$credentials" | jq -r '.Credentials.SecretAccessKey')  
    local session_token=$(echo "$credentials" | jq -r '.Credentials.SessionToken')
    local expiration=$(echo "$credentials" | jq -r '.Credentials.Expiration')
    
    if [[ "$test_only" == "true" ]]; then
        log "✅ Role assumption successful!"
        log "Account: $account ($account_id)"
        log "Role: $role_name"
        log "Expiration: $expiration"
        return 0
    fi
    
    # Cache credentials
    cat > "$CREDENTIALS_FILE" << EOF
export AWS_ACCESS_KEY_ID="$access_key"
export AWS_SECRET_ACCESS_KEY="$secret_key"
export AWS_SESSION_TOKEN="$session_token"
export AWS_DEFAULT_REGION="$(get_account_config "$account" "region")"
export TF_VAR_account_id="$account_id"
export TF_VAR_environment="$(get_account_config "$account" "environment")"
export TF_VAR_region="$(get_account_config "$account" "region")"
# Metadata
export ASSUMED_ROLE_ACCOUNT="$account"
export ASSUMED_ROLE_ARN="$role_arn"
export ASSUMED_ROLE_EXPIRATION="$expiration"
EOF
    
    log "✅ Credentials cached for account: $account"
    log "Expiration: $expiration"
}

# Export credentials to stdout for sourcing
export_credentials() {
    local account=$1
    
    if [[ ! -f "$CREDENTIALS_FILE" ]] || ! grep -q "ASSUMED_ROLE_ACCOUNT=\"$account\"" "$CREDENTIALS_FILE"; then
        log "Generating fresh credentials for $account..."
        assume_role "$account" false
    fi
    
    cat "$CREDENTIALS_FILE"
}

# Show current assumed role information
show_credentials() {
    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        warn "No cached credentials found"
        return 1
    fi
    
    source "$CREDENTIALS_FILE"
    
    log "Current assumed role information:"
    log "Account: ${ASSUMED_ROLE_ACCOUNT:-unknown}"
    log "Role ARN: ${ASSUMED_ROLE_ARN:-unknown}"  
    log "Region: ${AWS_DEFAULT_REGION:-unknown}"
    log "Expiration: ${ASSUMED_ROLE_EXPIRATION:-unknown}"
    
    # Test current credentials
    if aws sts get-caller-identity >/dev/null 2>&1; then
        local identity=$(aws sts get-caller-identity)
        log "✅ Credentials are valid"
        log "Current identity: $(echo "$identity" | jq -r '.Arn')"
    else
        warn "⚠️ Credentials appear to be expired or invalid"
    fi
}

# Clear cached credentials
clear_credentials() {
    if [[ -f "$CREDENTIALS_FILE" ]]; then
        rm -f "$CREDENTIALS_FILE"
        log "✅ Cached credentials cleared"
    else
        log "No cached credentials found"
    fi
}

# Main execution
main() {
    check_dependencies
    
    local account=""
    local action="assume"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --test)
                action="test"
                shift
                ;;
            --export)
                action="export"
                shift
                ;;
            --show)
                action="show"
                shift
                ;;
            --clear)
                action="clear"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                if [[ -z "$account" ]]; then
                    account="$1"
                else
                    error "Unknown option: $1"
                fi
                shift
                ;;
        esac
    done
    
    case $action in
        "test")
            [[ -z "$account" ]] && { usage; exit 1; }
            assume_role "$account" true
            ;;
        "export") 
            [[ -z "$account" ]] && { usage; exit 1; }
            export_credentials "$account"
            ;;
        "show")
            show_credentials
            ;;
        "clear")
            clear_credentials
            ;;
        "assume")
            [[ -z "$account" ]] && { usage; exit 1; }
            assume_role "$account" false
            log "To use these credentials, run:"
            log "source <(./scripts/assume-role.sh $account --export)"
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"