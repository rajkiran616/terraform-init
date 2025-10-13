#!/bin/bash
# Generate IAM Module Configuration from Existing AWS Resources
# This script scans your AWS account and generates the JSON configuration for the IAM module

set -e

# Configuration
OUTPUT_FILE="iam-config.tf"
TEMP_DIR="/tmp/terraform-iam-config"
ACCOUNT_ID=""
REGION=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Generate Terraform IAM module configuration from existing AWS resources.

Options:
    -o, --output FILE       Output file (default: iam-config.tf)
    -f, --filter PATTERN    Filter resources by name pattern
    -e, --exclude PATTERN   Exclude resources by name pattern
    --policies-only         Only generate policies
    --roles-only           Only generate roles
    --users-only           Only generate users
    --include-aws-managed   Include AWS managed policies
    --dry-run              Show what would be generated without creating files
    -h, --help             Display this help message

Examples:
    $0 -o my-iam.tf
    $0 --filter "MyApp*" --exclude "*Test*"
    $0 --roles-only --dry-run
EOF
}

# Parse command line arguments
OUTPUT_FILE="iam-config.tf"
FILTER_PATTERN=""
EXCLUDE_PATTERN=""
POLICIES_ONLY=false
ROLES_ONLY=false
USERS_ONLY=false
INCLUDE_AWS_MANAGED=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -f|--filter)
            FILTER_PATTERN="$2"
            shift 2
            ;;
        -e|--exclude)
            EXCLUDE_PATTERN="$2"
            shift 2
            ;;
        --policies-only)
            POLICIES_ONLY=true
            shift
            ;;
        --roles-only)
            ROLES_ONLY=true
            shift
            ;;
        --users-only)
            USERS_ONLY=true
            shift
            ;;
        --include-aws-managed)
            INCLUDE_AWS_MANAGED=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Setup
mkdir -p "$TEMP_DIR"

# Get AWS account info
log_info "Getting AWS account information..."
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
REGION=$(aws configure get region || echo "us-east-1")

log_info "AWS Account ID: $ACCOUNT_ID"
log_info "AWS Region: $REGION"

# Function to sanitize names for Terraform keys
sanitize_key() {
    local name="$1"
    # Convert to lowercase, replace spaces and special chars with hyphens
    echo "$name" | sed 's/[^a-zA-Z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g' | tr '[:upper:]' '[:lower:]'
}

# Function to escape JSON strings
escape_json() {
    echo "$1" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed 's/$/\\n/' | tr -d '\n'
}

# Function to filter resources
should_include() {
    local name="$1"
    
    # Apply exclude pattern first
    if [[ -n "$EXCLUDE_PATTERN" && "$name" == $EXCLUDE_PATTERN ]]; then
        return 1
    fi
    
    # Apply include pattern
    if [[ -n "$FILTER_PATTERN" && "$name" != $FILTER_PATTERN ]]; then
        return 1
    fi
    
    return 0
}

# Generate IAM Policies configuration
generate_policies() {
    log_info "Generating IAM policies configuration..."
    
    local policies_json=""
    local scope="Local"
    
    if [[ "$INCLUDE_AWS_MANAGED" == "true" ]]; then
        scope="All"
    fi
    
    # Get all policies
    aws iam list-policies --scope "$scope" --query 'Policies[*].[PolicyName,Arn,Description]' --output text > "$TEMP_DIR/policies.txt"
    
    while IFS=$'\t' read -r policy_name policy_arn description; do
        if should_include "$policy_name"; then
            log_info "Processing policy: $policy_name"
            
            # Get policy version
            local policy_document
            policy_document=$(aws iam get-policy-version --policy-arn "$policy_arn" --version-id v1 --query 'PolicyVersion.Document' --output json)
            
            # Sanitize key
            local key
            key=$(sanitize_key "$policy_name")
            
            # Build policy JSON
            local policy_config
            policy_config=$(cat << EOF
    "$key" = {
      name            = "$policy_name"
      description     = "$(escape_json "$description")"
      policy_document = jsonencode($(echo "$policy_document" | jq -c .))
      tags = {
        ImportedBy  = "terraform-script"
        Environment = "existing"
        OriginalArn = "$policy_arn"
      }
    }
EOF
            )
            
            if [[ -n "$policies_json" ]]; then
                policies_json="$policies_json,$policy_config"
            else
                policies_json="$policy_config"
            fi
        fi
    done < "$TEMP_DIR/policies.txt"
    
    echo "$policies_json"
}

# Generate IAM Roles configuration
generate_roles() {
    log_info "Generating IAM roles configuration..."
    
    local roles_json=""
    
    # Get all roles
    aws iam list-roles --query 'Roles[*].[RoleName,Description,AssumeRolePolicyDocument,Path,MaxSessionDuration]' --output json > "$TEMP_DIR/roles.json"
    
    while IFS= read -r role_data; do
        local role_name description assume_policy path max_session
        role_name=$(echo "$role_data" | jq -r '.[0]')
        description=$(echo "$role_data" | jq -r '.[1]')
        assume_policy=$(echo "$role_data" | jq -c '.[2]')
        path=$(echo "$role_data" | jq -r '.[3]')
        max_session=$(echo "$role_data" | jq -r '.[4]')
        
        # Skip AWS service roles
        if [[ "$role_name" == *"AWSServiceRole"* ]]; then
            continue
        fi
        
        if should_include "$role_name"; then
            log_info "Processing role: $role_name"
            
            # Get inline policies
            local inline_policies_json="[]"
            local inline_policy_names
            inline_policy_names=$(aws iam list-role-policies --role-name "$role_name" --query 'PolicyNames' --output json)
            
            if [[ "$inline_policy_names" != "[]" ]]; then
                local inline_policies="[]"
                while IFS= read -r policy_name; do
                    policy_name=$(echo "$policy_name" | tr -d '"')
                    local policy_document
                    policy_document=$(aws iam get-role-policy --role-name "$role_name" --policy-name "$policy_name" --query 'PolicyDocument' --output json)
                    
                    local inline_policy
                    inline_policy=$(cat << EOF
      {
        name   = "$policy_name"
        policy = jsonencode($(echo "$policy_document" | jq -c .))
      }
EOF
                    )
                    
                    if [[ "$inline_policies" == "[]" ]]; then
                        inline_policies="[$inline_policy]"
                    else
                        inline_policies="${inline_policies%]}, $inline_policy]"
                    fi
                done < <(echo "$inline_policy_names" | jq -r '.[]')
                inline_policies_json="$inline_policies"
            fi
            
            # Sanitize key
            local key
            key=$(sanitize_key "$role_name")
            
            # Build role JSON
            local role_config
            role_config=$(cat << EOF
    "$key" = {
      name                 = "$role_name"
      description          = "$(escape_json "$description")"
      path                 = "$path"
      assume_role_policy   = jsonencode($assume_policy)
      max_session_duration = $max_session
      inline_policies      = $inline_policies_json
      tags = {
        ImportedBy  = "terraform-script"
        Environment = "existing"
      }
    }
EOF
            )
            
            if [[ -n "$roles_json" ]]; then
                roles_json="$roles_json,$role_config"
            else
                roles_json="$role_config"
            fi
        fi
    done < <(cat "$TEMP_DIR/roles.json" | jq -c '.[]')
    
    echo "$roles_json"
}

# Generate IAM Users configuration
generate_users() {
    log_info "Generating IAM users configuration..."
    
    local users_json=""
    
    # Get all users
    aws iam list-users --query 'Users[*].[UserName,Path,CreateDate]' --output text > "$TEMP_DIR/users.txt"
    
    while IFS=$'\t' read -r user_name path create_date; do
        if should_include "$user_name"; then
            log_info "Processing user: $user_name"
            
            # Sanitize key
            local key
            key=$(sanitize_key "$user_name")
            
            # Build user JSON
            local user_config
            user_config=$(cat << EOF
    "$key" = {
      name = "$user_name"
      path = "$path"
      tags = {
        ImportedBy  = "terraform-script"
        Environment = "existing"
        CreatedDate = "$create_date"
      }
    }
EOF
            )
            
            if [[ -n "$users_json" ]]; then
                users_json="$users_json,$user_config"
            else
                users_json="$user_config"
            fi
        fi
    done < "$TEMP_DIR/users.txt"
    
    echo "$users_json"
}

# Generate IAM Groups configuration
generate_groups() {
    log_info "Generating IAM groups configuration..."
    
    local groups_json=""
    
    # Get all groups
    aws iam list-groups --query 'Groups[*].[GroupName,Path]' --output text > "$TEMP_DIR/groups.txt"
    
    while IFS=$'\t' read -r group_name path; do
        if should_include "$group_name"; then
            log_info "Processing group: $group_name"
            
            # Sanitize key
            local key
            key=$(sanitize_key "$group_name")
            
            # Build group JSON
            local group_config
            group_config=$(cat << EOF
    "$key" = {
      name = "$group_name"
      path = "$path"
    }
EOF
            )
            
            if [[ -n "$groups_json" ]]; then
                groups_json="$groups_json,$group_config"
            else
                groups_json="$group_config"
            fi
        fi
    done < "$TEMP_DIR/groups.txt"
    
    echo "$groups_json"
}

# Generate Role Policy Attachments
generate_role_policy_attachments() {
    log_info "Generating role policy attachments..."
    
    local attachments_json=""
    
    # Get all roles and their attached policies
    aws iam list-roles --query 'Roles[*].RoleName' --output text | tr '\t' '\n' > "$TEMP_DIR/role_names.txt"
    
    while IFS= read -r role_name; do
        if should_include "$role_name"; then
            # Get attached managed policies
            aws iam list-attached-role-policies --role-name "$role_name" --query 'AttachedPolicies[*].[PolicyName,PolicyArn]' --output text > "$TEMP_DIR/role_${role_name}_policies.txt"
            
            while IFS=$'\t' read -r policy_name policy_arn; do
                if [[ -n "$policy_name" ]]; then
                    local role_key policy_key attachment_key
                    role_key=$(sanitize_key "$role_name")
                    policy_key=$(sanitize_key "$policy_name")
                    attachment_key="${role_key}-${policy_key}"
                    
                    local attachment_config
                    if [[ "$policy_arn" == *":aws:policy/"* ]]; then
                        # AWS managed policy
                        attachment_config=$(cat << EOF
    "$attachment_key" = {
      role_name  = "$role_name"
      policy_arn = "$policy_arn"
    }
EOF
                        )
                    else
                        # Customer managed policy
                        attachment_config=$(cat << EOF
    "$attachment_key" = {
      role_name  = "$role_name"
      policy_arn = "$policy_arn"
      # policy_key = "$policy_key"  # Uncomment if referencing policy created in same module
    }
EOF
                        )
                    fi
                    
                    if [[ -n "$attachments_json" ]]; then
                        attachments_json="$attachments_json,$attachment_config"
                    else
                        attachments_json="$attachment_config"
                    fi
                fi
            done < "$TEMP_DIR/role_${role_name}_policies.txt"
        fi
    done < "$TEMP_DIR/role_names.txt"
    
    echo "$attachments_json"
}

# Generate the complete Terraform configuration
generate_config() {
    log_info "Generating complete Terraform configuration..."
    
    local config
    config=$(cat << 'EOF'
# Generated IAM Configuration
# Generated by terraform-iam-config script
# Account: ACCOUNT_ID
# Region: REGION
# Generated: $(date)

module "imported_iam" {
  source = "./modules/iam-management"

EOF
    )
    
    # Replace placeholders
    config=$(echo "$config" | sed "s/ACCOUNT_ID/$ACCOUNT_ID/g" | sed "s/REGION/$REGION/g")
    
    # Add policies if not filtered out
    if [[ "$ROLES_ONLY" == "false" && "$USERS_ONLY" == "false" ]]; then
        local policies_json
        policies_json=$(generate_policies)
        if [[ -n "$policies_json" ]]; then
            config="$config  # IAM Policies\n  iam_policies = {\n$policies_json\n  }\n\n"
        fi
    fi
    
    # Add roles if not filtered out
    if [[ "$POLICIES_ONLY" == "false" && "$USERS_ONLY" == "false" ]]; then
        local roles_json
        roles_json=$(generate_roles)
        if [[ -n "$roles_json" ]]; then
            config="$config  # IAM Roles\n  iam_roles = {\n$roles_json\n  }\n\n"
        fi
    fi
    
    # Add users if not filtered out
    if [[ "$POLICIES_ONLY" == "false" && "$ROLES_ONLY" == "false" ]]; then
        local users_json
        users_json=$(generate_users)
        if [[ -n "$users_json" ]]; then
            config="$config  # IAM Users\n  iam_users = {\n$users_json\n  }\n\n"
        fi
    fi
    
    # Add groups
    if [[ "$POLICIES_ONLY" == "false" && "$ROLES_ONLY" == "false" && "$USERS_ONLY" == "false" ]]; then
        local groups_json
        groups_json=$(generate_groups)
        if [[ -n "$groups_json" ]]; then
            config="$config  # IAM Groups\n  iam_groups = {\n$groups_json\n  }\n\n"
        fi
    fi
    
    # Add role policy attachments
    if [[ "$POLICIES_ONLY" == "false" && "$USERS_ONLY" == "false" ]]; then
        local attachments_json
        attachments_json=$(generate_role_policy_attachments)
        if [[ -n "$attachments_json" ]]; then
            config="$config  # IAM Role Policy Attachments\n  iam_role_policy_attachments = {\n$attachments_json\n  }\n\n"
        fi
    fi
    
    # Add common tags and close
    config="$config  # Common tags\n  common_tags = {\n    Project     = \"terraform-multi-account-organization\"\n    ManagedBy   = \"terraform\"\n    ImportedBy  = \"script\"\n    Environment = \"existing\"\n  }\n}\n"
    
    echo -e "$config"
}

# Main execution
main() {
    log_info "Starting IAM configuration generation..."
    log_info "Output file: $OUTPUT_FILE"
    
    # Check AWS CLI is available and configured
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not found. Please install and configure AWS CLI."
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS CLI not configured or no valid credentials found."
        exit 1
    fi
    
    # Generate configuration
    local generated_config
    generated_config=$(generate_config)
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN - Configuration that would be generated:"
        echo "$generated_config"
    else
        # Write to file
        echo "$generated_config" > "$OUTPUT_FILE"
        log_success "Configuration written to $OUTPUT_FILE"
        
        # Show summary
        log_info "Summary:"
        echo "  - Policies: $(grep -c '".*" = {' "$OUTPUT_FILE" | head -1 || echo 0)"
        echo "  - Total lines: $(wc -l < "$OUTPUT_FILE")"
        echo "  - Account ID: $ACCOUNT_ID"
        echo "  - Region: $REGION"
        
        log_info "Next steps:"
        echo "  1. Review the generated configuration: $OUTPUT_FILE"
        echo "  2. Adjust resource keys and names as needed"
        echo "  3. Run 'terraform plan' to see what will be imported"
        echo "  4. Use the generated import commands to import resources"
    fi
    
    # Cleanup
    rm -rf "$TEMP_DIR"
    
    log_success "IAM configuration generation completed!"
}

# Run main function
main "$@"
