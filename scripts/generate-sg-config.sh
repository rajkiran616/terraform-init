#!/bin/bash
# Generate Security Groups Module Configuration from Existing AWS Resources
# This script scans your AWS account and generates the JSON configuration for the Security Groups module

set -e

# Configuration
OUTPUT_FILE="sg-config.tf"
TEMP_DIR="/tmp/terraform-sg-config"
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

Generate Terraform Security Groups module configuration from existing AWS resources.

Options:
    -o, --output FILE       Output file (default: sg-config.tf)
    -r, --region REGION     AWS region to scan (default: current region)
    -v, --vpc-id VPC_ID     Specific VPC ID to scan (default: all VPCs)
    -g, --group-id SG_ID    Specific Security Group ID to scan
    -f, --filter PATTERN    Filter resources by name pattern
    -e, --exclude PATTERN   Exclude resources by name pattern
    --include-default       Include default security groups
    --dry-run              Show what would be generated without creating files
    -h, --help             Display this help message

Examples:
    $0 -o my-sg.tf
    $0 --vpc-id vpc-12345678
    $0 --group-id sg-12345678
    $0 --filter "web-*" --exclude "*test*"
    $0 --dry-run
EOF
}

# Parse command line arguments
OUTPUT_FILE="sg-config.tf"
TARGET_REGION=""
TARGET_VPC_ID=""
TARGET_GROUP_ID=""
FILTER_PATTERN=""
EXCLUDE_PATTERN=""
INCLUDE_DEFAULT=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -r|--region)
            TARGET_REGION="$2"
            shift 2
            ;;
        -v|--vpc-id)
            TARGET_VPC_ID="$2"
            shift 2
            ;;
        -g|--group-id)
            TARGET_GROUP_ID="$2"
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
        --include-default)
            INCLUDE_DEFAULT=true
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
REGION=${TARGET_REGION:-$(aws configure get region || echo "us-east-1")}

log_info "AWS Account ID: $ACCOUNT_ID"
log_info "AWS Region: $REGION"

# Function to sanitize names for Terraform keys
sanitize_key() {
    local name="$1"
    # Convert to lowercase, replace spaces and special chars with hyphens
    echo "$name" | sed 's/[^a-zA-Z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g' | tr '[:upper:]' '[:lower:]'
}

# Function to get tag value
get_tag_value() {
    local tags="$1"
    local tag_key="$2"
    echo "$tags" | jq -r --arg key "$tag_key" '.[] | select(.Key == $key) | .Value'
}

# Function to format tags for Terraform
format_tags() {
    local tags="$1"
    local tag_config=""
    
    if [[ "$tags" != "null" && "$tags" != "[]" ]]; then
        while IFS= read -r tag; do
            local key value
            key=$(echo "$tag" | jq -r '.Key')
            value=$(echo "$tag" | jq -r '.Value')
            
            # Skip AWS tags
            if [[ "$key" == aws:* ]]; then
                continue
            fi
            
            if [[ -n "$tag_config" ]]; then
                tag_config="$tag_config,\n        $key = \"$value\""
            else
                tag_config="$key = \"$value\""
            fi
        done < <(echo "$tags" | jq -c '.[]')
    fi
    
    echo -e "$tag_config"
}

# Function to filter resources
should_include() {
    local name="$1"
    local group_name="$2"
    local is_default="${3:-false}"
    
    # Skip default security groups unless explicitly included
    if [[ "$group_name" == "default" && "$INCLUDE_DEFAULT" == "false" ]]; then
        return 1
    fi
    
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

# Function to format CIDR blocks
format_cidr_blocks() {
    local cidrs="$1"
    if [[ "$cidrs" == "null" || "$cidrs" == "[]" ]]; then
        echo "null"
        return
    fi
    
    local cidr_list=""
    while IFS= read -r cidr; do
        cidr=$(echo "$cidr" | tr -d '"')
        if [[ -n "$cidr_list" ]]; then
            cidr_list="$cidr_list, \"$cidr\""
        else
            cidr_list="\"$cidr\""
        fi
    done < <(echo "$cidrs" | jq -r '.[]')
    
    echo "[$cidr_list]"
}

# Generate Security Groups configuration
generate_security_groups() {
    log_info "Generating Security Groups configuration..."
    
    local sgs_json=""
    local query="SecurityGroups[*].[GroupId,GroupName,Description,VpcId,Tags]"
    
    # Build filters
    local filters=""
    if [[ -n "$TARGET_VPC_ID" ]]; then
        filters="--filters Name=vpc-id,Values=$TARGET_VPC_ID"
    fi
    
    if [[ -n "$TARGET_GROUP_ID" ]]; then
        aws ec2 describe-security-groups --group-ids "$TARGET_GROUP_ID" --region "$REGION" --query "$query" --output json > "$TEMP_DIR/security_groups.json"
    else
        aws ec2 describe-security-groups $filters --region "$REGION" --query "$query" --output json > "$TEMP_DIR/security_groups.json"
    fi
    
    while IFS= read -r sg_data; do
        local group_id group_name description vpc_id tags
        group_id=$(echo "$sg_data" | jq -r '.[0]')
        group_name=$(echo "$sg_data" | jq -r '.[1]')
        description=$(echo "$sg_data" | jq -r '.[2]')
        vpc_id=$(echo "$sg_data" | jq -r '.[3]')
        tags=$(echo "$sg_data" | jq -c '.[4]')
        
        # Get SG name from tags if available
        local sg_name
        sg_name=$(get_tag_value "$tags" "Name")
        if [[ "$sg_name" == "null" || -z "$sg_name" ]]; then
            sg_name="$group_name"
        fi
        
        if should_include "$sg_name" "$group_name"; then
            log_info "Processing Security Group: $sg_name ($group_id)"
            
            # Get VPC name for reference
            local vpc_name=""
            if [[ "$vpc_id" != "null" ]]; then
                vpc_name=$(aws ec2 describe-vpcs --vpc-ids "$vpc_id" --region "$REGION" --query 'Vpcs[0].Tags[?Key==`Name`].Value | [0]' --output text 2>/dev/null || echo "")
                if [[ "$vpc_name" == "None" || -z "$vpc_name" ]]; then
                    vpc_name="$vpc_id"
                fi
            fi
            
            # Sanitize key
            local key
            key=$(sanitize_key "$sg_name")
            
            # Format tags
            local tag_config
            tag_config=$(format_tags "$tags")
            
            # Build security group JSON
            local sg_config
            if [[ "$group_name" == "default" ]]; then
                # For default security groups, we typically don't recreate them
                sg_config=$(cat << EOF
    # "$key" = {
    #   name        = "$group_name"  # Default SG - typically not recreated
    #   description = "$(echo "$description" | sed 's/"/\\"/g')"
    #   vpc_id      = "$vpc_id"  # Reference to VPC: $vpc_name
    #   tags = {
    #     ImportedBy      = "terraform-script"
    #     Environment     = "existing"
    #     OriginalGroupId = "$group_id"
$([ -n "$tag_config" ] && echo "    #     $tag_config")
    #   }
    # }
EOF
                )
            else
                sg_config=$(cat << EOF
    "$key" = {
      name        = "$group_name"
      description = "$(echo "$description" | sed 's/"/\\"/g')"
      vpc_id      = "$vpc_id"  # Reference to VPC: $vpc_name
      tags = {
        ImportedBy      = "terraform-script"
        Environment     = "existing"
        OriginalGroupId = "$group_id"
$([ -n "$tag_config" ] && echo "        $tag_config")
      }
    }
EOF
                )
            fi
            
            if [[ -n "$sgs_json" ]]; then
                sgs_json="$sgs_json,$sg_config"
            else
                sgs_json="$sg_config"
            fi
        fi
    done < <(cat "$TEMP_DIR/security_groups.json" | jq -c '.[]')
    
    echo "$sgs_json"
}

# Generate Security Group Rules configuration
generate_security_group_rules() {
    log_info "Generating Security Group Rules configuration..."
    
    local rules_json=""
    local query="SecurityGroups[*].[GroupId,GroupName,IpPermissions,IpPermissionsEgress,Tags]"
    
    # Build filters
    local filters=""
    if [[ -n "$TARGET_VPC_ID" ]]; then
        filters="--filters Name=vpc-id,Values=$TARGET_VPC_ID"
    fi
    
    if [[ -n "$TARGET_GROUP_ID" ]]; then
        aws ec2 describe-security-groups --group-ids "$TARGET_GROUP_ID" --region "$REGION" --query "$query" --output json > "$TEMP_DIR/sg_rules.json"
    else
        aws ec2 describe-security-groups $filters --region "$REGION" --query "$query" --output json > "$TEMP_DIR/sg_rules.json"
    fi
    
    while IFS= read -r sg_data; do
        local group_id group_name ingress_rules egress_rules tags
        group_id=$(echo "$sg_data" | jq -r '.[0]')
        group_name=$(echo "$sg_data" | jq -r '.[1]')
        ingress_rules=$(echo "$sg_data" | jq -c '.[2]')
        egress_rules=$(echo "$sg_data" | jq -c '.[3]')
        tags=$(echo "$sg_data" | jq -c '.[4]')
        
        # Get SG name from tags if available
        local sg_name
        sg_name=$(get_tag_value "$tags" "Name")
        if [[ "$sg_name" == "null" || -z "$sg_name" ]]; then
            sg_name="$group_name"
        fi
        
        # Skip default security groups for rules (they have special handling)
        if [[ "$group_name" == "default" && "$INCLUDE_DEFAULT" == "false" ]]; then
            continue
        fi
        
        if should_include "$sg_name" "$group_name"; then
            log_info "Processing rules for Security Group: $sg_name ($group_id)"
            
            local sg_key
            sg_key=$(sanitize_key "$sg_name")
            
            # Process ingress rules
            if [[ "$ingress_rules" != "[]" && "$ingress_rules" != "null" ]]; then
                local rule_index=0
                while IFS= read -r rule; do
                    local from_port to_port protocol description
                    from_port=$(echo "$rule" | jq -r '.FromPort // -1')
                    to_port=$(echo "$rule" | jq -r '.ToPort // -1')
                    protocol=$(echo "$rule" | jq -r '.IpProtocol')
                    
                    # Handle protocol specifics
                    if [[ "$protocol" == "-1" ]]; then
                        from_port=0
                        to_port=0
                    elif [[ "$from_port" == "-1" ]]; then
                        from_port=0
                        to_port=65535
                    fi
                    
                    # Process CIDR blocks
                    local cidr_blocks
                    cidr_blocks=$(echo "$rule" | jq -c '.IpRanges[].CidrIp')
                    if [[ "$cidr_blocks" != "" ]]; then
                        local cidrs
                        cidrs=$(echo "$rule" | jq -c '[.IpRanges[].CidrIp]')
                        local formatted_cidrs
                        formatted_cidrs=$(format_cidr_blocks "$cidrs")
                        
                        local rule_key="${sg_key}-ingress-${rule_index}"
                        local rule_config
                        rule_config=$(cat << EOF
    "$rule_key" = {
      security_group_key = "$sg_key"  # Reference to SG: $sg_name
      type               = "ingress"
      from_port          = $from_port
      to_port            = $to_port
      protocol           = "$protocol"
      description        = "Ingress rule from CIDR blocks"
      cidr_blocks        = $formatted_cidrs
    }
EOF
                        )
                        
                        if [[ -n "$rules_json" ]]; then
                            rules_json="$rules_json,$rule_config"
                        else
                            rules_json="$rule_config"
                        fi
                        ((rule_index++))
                    fi
                    
                    # Process referenced security groups
                    local ref_groups
                    ref_groups=$(echo "$rule" | jq -c '.UserIdGroupPairs[]?')
                    while IFS= read -r ref_group && [[ -n "$ref_group" ]]; do
                        local ref_group_id ref_description
                        ref_group_id=$(echo "$ref_group" | jq -r '.GroupId')
                        ref_description=$(echo "$ref_group" | jq -r '.Description // ""')
                        
                        # Get referenced SG name
                        local ref_sg_name
                        ref_sg_name=$(aws ec2 describe-security-groups --group-ids "$ref_group_id" --region "$REGION" --query 'SecurityGroups[0].Tags[?Key==`Name`].Value | [0]' --output text 2>/dev/null || echo "")
                        if [[ "$ref_sg_name" == "None" || -z "$ref_sg_name" ]]; then
                            ref_sg_name=$(aws ec2 describe-security-groups --group-ids "$ref_group_id" --region "$REGION" --query 'SecurityGroups[0].GroupName' --output text 2>/dev/null || echo "$ref_group_id")
                        fi
                        
                        local rule_key="${sg_key}-ingress-sg-${rule_index}"
                        local rule_config
                        rule_config=$(cat << EOF
    "$rule_key" = {
      security_group_key        = "$sg_key"  # Reference to SG: $sg_name
      type                      = "ingress"
      from_port                 = $from_port
      to_port                   = $to_port
      protocol                  = "$protocol"
      description               = "$(echo "$ref_description" | sed 's/"/\\"/g')"
      source_security_group_id  = "$ref_group_id"  # Reference to SG: $ref_sg_name
      # source_security_group_key = "$(sanitize_key "$ref_sg_name")"  # Uncomment if referencing SG created in same module
    }
EOF
                        )
                        
                        if [[ -n "$rules_json" ]]; then
                            rules_json="$rules_json,$rule_config"
                        else
                            rules_json="$rule_config"
                        fi
                        ((rule_index++))
                    done < <(echo "$rule" | jq -c '.UserIdGroupPairs[]?' 2>/dev/null || echo "")
                    
                done < <(echo "$ingress_rules" | jq -c '.[]')
            fi
            
            # Process egress rules
            if [[ "$egress_rules" != "[]" && "$egress_rules" != "null" ]]; then
                local rule_index=1000  # Start egress rules at 1000 to avoid conflicts
                while IFS= read -r rule; do
                    local from_port to_port protocol
                    from_port=$(echo "$rule" | jq -r '.FromPort // -1')
                    to_port=$(echo "$rule" | jq -r '.ToPort // -1')
                    protocol=$(echo "$rule" | jq -r '.IpProtocol')
                    
                    # Handle protocol specifics
                    if [[ "$protocol" == "-1" ]]; then
                        from_port=0
                        to_port=0
                    elif [[ "$from_port" == "-1" ]]; then
                        from_port=0
                        to_port=65535
                    fi
                    
                    # Process CIDR blocks
                    local cidr_blocks
                    cidr_blocks=$(echo "$rule" | jq -c '.IpRanges[].CidrIp')
                    if [[ "$cidr_blocks" != "" ]]; then
                        local cidrs
                        cidrs=$(echo "$rule" | jq -c '[.IpRanges[].CidrIp]')
                        local formatted_cidrs
                        formatted_cidrs=$(format_cidr_blocks "$cidrs")
                        
                        local rule_key="${sg_key}-egress-${rule_index}"
                        local rule_config
                        rule_config=$(cat << EOF
    "$rule_key" = {
      security_group_key = "$sg_key"  # Reference to SG: $sg_name
      type               = "egress"
      from_port          = $from_port
      to_port            = $to_port
      protocol           = "$protocol"
      description        = "Egress rule to CIDR blocks"
      cidr_blocks        = $formatted_cidrs
    }
EOF
                        )
                        
                        if [[ -n "$rules_json" ]]; then
                            rules_json="$rules_json,$rule_config"
                        else
                            rules_json="$rule_config"
                        fi
                        ((rule_index++))
                    fi
                    
                    # Process referenced security groups for egress
                    local ref_groups
                    ref_groups=$(echo "$rule" | jq -c '.UserIdGroupPairs[]?')
                    while IFS= read -r ref_group && [[ -n "$ref_group" ]]; do
                        local ref_group_id ref_description
                        ref_group_id=$(echo "$ref_group" | jq -r '.GroupId')
                        ref_description=$(echo "$ref_group" | jq -r '.Description // ""')
                        
                        # Get referenced SG name
                        local ref_sg_name
                        ref_sg_name=$(aws ec2 describe-security-groups --group-ids "$ref_group_id" --region "$REGION" --query 'SecurityGroups[0].Tags[?Key==`Name`].Value | [0]' --output text 2>/dev/null || echo "")
                        if [[ "$ref_sg_name" == "None" || -z "$ref_sg_name" ]]; then
                            ref_sg_name=$(aws ec2 describe-security-groups --group-ids "$ref_group_id" --region "$REGION" --query 'SecurityGroups[0].GroupName' --output text 2>/dev/null || echo "$ref_group_id")
                        fi
                        
                        local rule_key="${sg_key}-egress-sg-${rule_index}"
                        local rule_config
                        rule_config=$(cat << EOF
    "$rule_key" = {
      security_group_key        = "$sg_key"  # Reference to SG: $sg_name
      type                      = "egress"
      from_port                 = $from_port
      to_port                   = $to_port
      protocol                  = "$protocol"
      description               = "$(echo "$ref_description" | sed 's/"/\\"/g')"
      source_security_group_id  = "$ref_group_id"  # Reference to SG: $ref_sg_name
      # source_security_group_key = "$(sanitize_key "$ref_sg_name")"  # Uncomment if referencing SG created in same module
    }
EOF
                        )
                        
                        if [[ -n "$rules_json" ]]; then
                            rules_json="$rules_json,$rule_config"
                        else
                            rules_json="$rule_config"
                        fi
                        ((rule_index++))
                    done < <(echo "$rule" | jq -c '.UserIdGroupPairs[]?' 2>/dev/null || echo "")
                    
                done < <(echo "$egress_rules" | jq -c '.[]')
            fi
        fi
    done < <(cat "$TEMP_DIR/sg_rules.json" | jq -c '.[]')
    
    echo "$rules_json"
}

# Generate the complete Terraform configuration
generate_config() {
    log_info "Generating complete Terraform configuration..."
    
    local config
    config=$(cat << 'EOF'
# Generated Security Groups Configuration
# Generated by terraform-sg-config script
# Account: ACCOUNT_ID
# Region: REGION
# Generated: $(date)

module "imported_security_groups" {
  source = "./modules/security-groups"

EOF
    )
    
    # Replace placeholders
    config=$(echo "$config" | sed "s/ACCOUNT_ID/$ACCOUNT_ID/g" | sed "s/REGION/$REGION/g")
    
    # Generate Security Groups
    local sgs_json
    sgs_json=$(generate_security_groups)
    if [[ -n "$sgs_json" ]]; then
        config="$config  # Security Groups\n  security_groups = {\n$sgs_json\n  }\n\n"
    fi
    
    # Generate Security Group Rules
    local rules_json
    rules_json=$(generate_security_group_rules)
    if [[ -n "$rules_json" ]]; then
        config="$config  # Security Group Rules\n  security_group_rules = {\n$rules_json\n  }\n\n"
    fi
    
    # Add common tags and close
    config="$config  # Common tags\n  common_tags = {\n    Project     = \"terraform-multi-account-organization\"\n    ManagedBy   = \"terraform\"\n    ImportedBy  = \"script\"\n    Environment = \"existing\"\n    AccountId   = \"$ACCOUNT_ID\"\n    Region      = \"$REGION\"\n  }\n}\n"
    
    echo -e "$config"
}

# Main execution
main() {
    log_info "Starting Security Groups configuration generation..."
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
    
    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        log_error "jq not found. Please install jq for JSON processing."
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
        echo "  - Security Groups: $(grep -c 'security_groups = {' "$OUTPUT_FILE" || echo 0)"
        echo "  - Security Group Rules: $(grep -c 'security_group_rules = {' "$OUTPUT_FILE" || echo 0)"
        echo "  - Total lines: $(wc -l < "$OUTPUT_FILE")"
        echo "  - Account ID: $ACCOUNT_ID"
        echo "  - Region: $REGION"
        
        log_info "Next steps:"
        echo "  1. Review the generated configuration: $OUTPUT_FILE"
        echo "  2. Adjust resource keys and references as needed"
        echo "  3. Update security group cross-references if needed"
        echo "  4. Run 'terraform plan' to see what will be imported"
        echo "  5. Use terraform import commands to import resources"
    fi
    
    # Cleanup
    rm -rf "$TEMP_DIR"
    
    log_success "Security Groups configuration generation completed!"
}

# Run main function
main "$@"
