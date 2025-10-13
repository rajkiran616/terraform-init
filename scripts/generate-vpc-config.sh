#!/bin/bash
# Generate VPC Module Configuration from Existing AWS Resources
# This script scans your AWS account and generates the JSON configuration for the VPC module

set -e

# Configuration
OUTPUT_FILE="vpc-config.tf"
TEMP_DIR="/tmp/terraform-vpc-config"
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

Generate Terraform VPC module configuration from existing AWS resources.

Options:
    -o, --output FILE       Output file (default: vpc-config.tf)
    -r, --region REGION     AWS region to scan (default: current region)
    -v, --vpc-id VPC_ID     Specific VPC ID to scan (default: all VPCs)
    -f, --filter PATTERN    Filter resources by name pattern
    -e, --exclude PATTERN   Exclude resources by name pattern
    --include-default-vpc   Include default VPC
    --dry-run              Show what would be generated without creating files
    -h, --help             Display this help message

Examples:
    $0 -o my-vpc.tf
    $0 --vpc-id vpc-12345678
    $0 --filter "prod-*" --exclude "*test*"
    $0 --dry-run
EOF
}

# Parse command line arguments
OUTPUT_FILE="vpc-config.tf"
TARGET_REGION=""
TARGET_VPC_ID=""
FILTER_PATTERN=""
EXCLUDE_PATTERN=""
INCLUDE_DEFAULT_VPC=false
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
        -f|--filter)
            FILTER_PATTERN="$2"
            shift 2
            ;;
        -e|--exclude)
            EXCLUDE_PATTERN="$2"
            shift 2
            ;;
        --include-default-vpc)
            INCLUDE_DEFAULT_VPC=true
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
    local is_default="${2:-false}"
    
    # Skip default VPC unless explicitly included
    if [[ "$is_default" == "true" && "$INCLUDE_DEFAULT_VPC" == "false" ]]; then
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

# Generate VPCs configuration
generate_vpcs() {
    log_info "Generating VPCs configuration..."
    
    local vpcs_json=""
    local query="Vpcs[*].[VpcId,CidrBlock,IsDefault,State,Tags]"
    
    if [[ -n "$TARGET_VPC_ID" ]]; then
        aws ec2 describe-vpcs --vpc-ids "$TARGET_VPC_ID" --region "$REGION" --query "$query" --output json > "$TEMP_DIR/vpcs.json"
    else
        aws ec2 describe-vpcs --region "$REGION" --query "$query" --output json > "$TEMP_DIR/vpcs.json"
    fi
    
    while IFS= read -r vpc_data; do
        local vpc_id cidr_block is_default state tags
        vpc_id=$(echo "$vpc_data" | jq -r '.[0]')
        cidr_block=$(echo "$vpc_data" | jq -r '.[1]')
        is_default=$(echo "$vpc_data" | jq -r '.[2]')
        state=$(echo "$vpc_data" | jq -r '.[3]')
        tags=$(echo "$vpc_data" | jq -c '.[4]')
        
        # Skip non-available VPCs
        if [[ "$state" != "available" ]]; then
            continue
        fi
        
        # Get VPC name from tags
        local vpc_name
        vpc_name=$(get_tag_value "$tags" "Name")
        if [[ "$vpc_name" == "null" || -z "$vpc_name" ]]; then
            vpc_name="$vpc_id"
        fi
        
        if should_include "$vpc_name" "$is_default"; then
            log_info "Processing VPC: $vpc_name ($vpc_id)"
            
            # Get additional VPC attributes
            local vpc_details
            vpc_details=$(aws ec2 describe-vpc-attribute --vpc-id "$vpc_id" --attribute enableDnsHostnames --region "$REGION" --output json)
            local dns_hostnames
            dns_hostnames=$(echo "$vpc_details" | jq -r '.EnableDnsHostnames.Value')
            
            vpc_details=$(aws ec2 describe-vpc-attribute --vpc-id "$vpc_id" --attribute enableDnsSupport --region "$REGION" --output json)
            local dns_support
            dns_support=$(echo "$vpc_details" | jq -r '.EnableDnsSupport.Value')
            
            # Sanitize key
            local key
            key=$(sanitize_key "$vpc_name")
            
            # Format tags
            local tag_config
            tag_config=$(format_tags "$tags")
            
            # Build VPC JSON
            local vpc_config
            vpc_config=$(cat << EOF
    "$key" = {
      cidr_block           = "$cidr_block"
      enable_dns_hostnames = $dns_hostnames
      enable_dns_support   = $dns_support
      tags = {
        ImportedBy    = "terraform-script"
        Environment   = "existing"
        OriginalVpcId = "$vpc_id"
$([ -n "$tag_config" ] && echo "        $tag_config")
      }
    }
EOF
            )
            
            if [[ -n "$vpcs_json" ]]; then
                vpcs_json="$vpcs_json,$vpc_config"
            else
                vpcs_json="$vpc_config"
            fi
        fi
    done < <(cat "$TEMP_DIR/vpcs.json" | jq -c '.[]')
    
    echo "$vpcs_json"
}

# Generate Internet Gateways configuration
generate_internet_gateways() {
    log_info "Generating Internet Gateways configuration..."
    
    local igws_json=""
    
    aws ec2 describe-internet-gateways --region "$REGION" --query 'InternetGateways[*].[InternetGatewayId,Attachments[0].VpcId,Tags]' --output json > "$TEMP_DIR/igws.json"
    
    while IFS= read -r igw_data; do
        local igw_id vpc_id tags
        igw_id=$(echo "$igw_data" | jq -r '.[0]')
        vpc_id=$(echo "$igw_data" | jq -r '.[1]')
        tags=$(echo "$igw_data" | jq -c '.[2]')
        
        # Skip if not attached to a VPC
        if [[ "$vpc_id" == "null" ]]; then
            continue
        fi
        
        # If targeting specific VPC, skip others
        if [[ -n "$TARGET_VPC_ID" && "$vpc_id" != "$TARGET_VPC_ID" ]]; then
            continue
        fi
        
        # Get IGW name from tags
        local igw_name
        igw_name=$(get_tag_value "$tags" "Name")
        if [[ "$igw_name" == "null" || -z "$igw_name" ]]; then
            igw_name="igw-${vpc_id}"
        fi
        
        if should_include "$igw_name"; then
            log_info "Processing IGW: $igw_name ($igw_id)"
            
            # Get VPC name for reference
            local vpc_name
            vpc_name=$(aws ec2 describe-vpcs --vpc-ids "$vpc_id" --region "$REGION" --query 'Vpcs[0].Tags[?Key==`Name`].Value | [0]' --output text)
            if [[ "$vpc_name" == "None" || -z "$vpc_name" ]]; then
                vpc_name="$vpc_id"
            fi
            
            # Sanitize keys
            local key vpc_key
            key=$(sanitize_key "$igw_name")
            vpc_key=$(sanitize_key "$vpc_name")
            
            # Format tags
            local tag_config
            tag_config=$(format_tags "$tags")
            
            # Build IGW JSON
            local igw_config
            igw_config=$(cat << EOF
    "$key" = {
      vpc_key = "$vpc_key"  # Reference to VPC: $vpc_name
      tags = {
        ImportedBy    = "terraform-script"
        Environment   = "existing"
        OriginalIgwId = "$igw_id"
$([ -n "$tag_config" ] && echo "        $tag_config")
      }
    }
EOF
            )
            
            if [[ -n "$igws_json" ]]; then
                igws_json="$igws_json,$igw_config"
            else
                igws_json="$igw_config"
            fi
        fi
    done < <(cat "$TEMP_DIR/igws.json" | jq -c '.[]')
    
    echo "$igws_json"
}

# Generate Subnets configuration
generate_subnets() {
    log_info "Generating Subnets configuration..."
    
    local subnets_json=""
    local query="Subnets[*].[SubnetId,VpcId,CidrBlock,AvailabilityZone,MapPublicIpOnLaunch,Tags]"
    
    if [[ -n "$TARGET_VPC_ID" ]]; then
        aws ec2 describe-subnets --filters "Name=vpc-id,Values=$TARGET_VPC_ID" --region "$REGION" --query "$query" --output json > "$TEMP_DIR/subnets.json"
    else
        aws ec2 describe-subnets --region "$REGION" --query "$query" --output json > "$TEMP_DIR/subnets.json"
    fi
    
    while IFS= read -r subnet_data; do
        local subnet_id vpc_id cidr_block az map_public_ip tags
        subnet_id=$(echo "$subnet_data" | jq -r '.[0]')
        vpc_id=$(echo "$subnet_data" | jq -r '.[1]')
        cidr_block=$(echo "$subnet_data" | jq -r '.[2]')
        az=$(echo "$subnet_data" | jq -r '.[3]')
        map_public_ip=$(echo "$subnet_data" | jq -r '.[4]')
        tags=$(echo "$subnet_data" | jq -c '.[5]')
        
        # Get subnet name from tags
        local subnet_name
        subnet_name=$(get_tag_value "$tags" "Name")
        if [[ "$subnet_name" == "null" || -z "$subnet_name" ]]; then
            subnet_name="subnet-$subnet_id"
        fi
        
        if should_include "$subnet_name"; then
            log_info "Processing Subnet: $subnet_name ($subnet_id)"
            
            # Get VPC name for reference
            local vpc_name
            vpc_name=$(aws ec2 describe-vpcs --vpc-ids "$vpc_id" --region "$REGION" --query 'Vpcs[0].Tags[?Key==`Name`].Value | [0]' --output text)
            if [[ "$vpc_name" == "None" || -z "$vpc_name" ]]; then
                vpc_name="$vpc_id"
            fi
            
            # Determine tier based on public IP mapping and route table
            local tier="private"
            if [[ "$map_public_ip" == "true" ]]; then
                tier="public"
            fi
            
            # Check for database-specific naming
            if [[ "$subnet_name" == *"database"* || "$subnet_name" == *"db"* ]]; then
                tier="database"
            fi
            
            # Sanitize keys
            local key vpc_key
            key=$(sanitize_key "$subnet_name")
            vpc_key=$(sanitize_key "$vpc_name")
            
            # Format tags
            local tag_config
            tag_config=$(format_tags "$tags")
            
            # Build subnet JSON
            local subnet_config
            subnet_config=$(cat << EOF
    "$key" = {
      vpc_key                 = "$vpc_key"  # Reference to VPC: $vpc_name
      cidr_block              = "$cidr_block"
      availability_zone       = "$az"
      map_public_ip_on_launch = $map_public_ip
      tier                    = "$tier"
      tags = {
        ImportedBy       = "terraform-script"
        Environment      = "existing"
        OriginalSubnetId = "$subnet_id"
$([ -n "$tag_config" ] && echo "        $tag_config")
      }
    }
EOF
            )
            
            if [[ -n "$subnets_json" ]]; then
                subnets_json="$subnets_json,$subnet_config"
            else
                subnets_json="$subnet_config"
            fi
        fi
    done < <(cat "$TEMP_DIR/subnets.json" | jq -c '.[]')
    
    echo "$subnets_json"
}

# Generate NAT Gateways and Elastic IPs configuration
generate_nat_gateways_and_eips() {
    log_info "Generating NAT Gateways and Elastic IPs configuration..."
    
    local eips_json=""
    local nat_gws_json=""
    
    # Get NAT Gateways
    local query="NatGateways[*].[NatGatewayId,SubnetId,NatGatewayAddresses[0].AllocationId,NatGatewayAddresses[0].PublicIp,Tags]"
    
    if [[ -n "$TARGET_VPC_ID" ]]; then
        aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$TARGET_VPC_ID" --region "$REGION" --query "$query" --output json > "$TEMP_DIR/nat_gateways.json"
    else
        aws ec2 describe-nat-gateways --region "$REGION" --query "$query" --output json > "$TEMP_DIR/nat_gateways.json"
    fi
    
    while IFS= read -r nat_data; do
        local nat_id subnet_id allocation_id public_ip tags
        nat_id=$(echo "$nat_data" | jq -r '.[0]')
        subnet_id=$(echo "$nat_data" | jq -r '.[1]')
        allocation_id=$(echo "$nat_data" | jq -r '.[2]')
        public_ip=$(echo "$nat_data" | jq -r '.[3]')
        tags=$(echo "$nat_data" | jq -c '.[4]')
        
        # Get NAT gateway name from tags
        local nat_name
        nat_name=$(get_tag_value "$tags" "Name")
        if [[ "$nat_name" == "null" || -z "$nat_name" ]]; then
            nat_name="nat-gw-$nat_id"
        fi
        
        # Get subnet name for reference
        local subnet_name
        subnet_name=$(aws ec2 describe-subnets --subnet-ids "$subnet_id" --region "$REGION" --query 'Subnets[0].Tags[?Key==`Name`].Value | [0]' --output text)
        if [[ "$subnet_name" == "None" || -z "$subnet_name" ]]; then
            subnet_name="subnet-$subnet_id"
        fi
        
        if should_include "$nat_name"; then
            log_info "Processing NAT Gateway: $nat_name ($nat_id)"
            
            # Generate EIP configuration
            local eip_key nat_key subnet_key
            eip_key=$(sanitize_key "eip-$nat_name")
            nat_key=$(sanitize_key "$nat_name")
            subnet_key=$(sanitize_key "$subnet_name")
            
            # EIP configuration
            local eip_config
            eip_config=$(cat << EOF
    "$eip_key" = {
      tags = {
        ImportedBy      = "terraform-script"
        Environment     = "existing"
        OriginalEipId   = "$allocation_id"
        PublicIp        = "$public_ip"
        AssociatedNatGw = "$nat_name"
      }
    }
EOF
            )
            
            # NAT Gateway configuration
            local nat_config
            nat_config=$(cat << EOF
    "$nat_key" = {
      subnet_key = "$subnet_key"  # Reference to subnet: $subnet_name
      eip_key    = "$eip_key"     # Reference to EIP created above
      tags = {
        ImportedBy     = "terraform-script"
        Environment    = "existing"
        OriginalNatGwId = "$nat_id"
      }
    }
EOF
            )
            
            # Add to collections
            if [[ -n "$eips_json" ]]; then
                eips_json="$eips_json,$eip_config"
            else
                eips_json="$eip_config"
            fi
            
            if [[ -n "$nat_gws_json" ]]; then
                nat_gws_json="$nat_gws_json,$nat_config"
            else
                nat_gws_json="$nat_config"
            fi
        fi
    done < <(cat "$TEMP_DIR/nat_gateways.json" | jq -c '.[]')
    
    echo "$eips_json|$nat_gws_json"
}

# Generate Route Tables configuration
generate_route_tables() {
    log_info "Generating Route Tables configuration..."
    
    local route_tables_json=""
    local associations_json=""
    
    local query="RouteTables[*].[RouteTableId,VpcId,Routes,Associations,Tags]"
    
    if [[ -n "$TARGET_VPC_ID" ]]; then
        aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$TARGET_VPC_ID" --region "$REGION" --query "$query" --output json > "$TEMP_DIR/route_tables.json"
    else
        aws ec2 describe-route-tables --region "$REGION" --query "$query" --output json > "$TEMP_DIR/route_tables.json"
    fi
    
    while IFS= read -r rt_data; do
        local rt_id vpc_id routes associations tags
        rt_id=$(echo "$rt_data" | jq -r '.[0]')
        vpc_id=$(echo "$rt_data" | jq -r '.[1]')
        routes=$(echo "$rt_data" | jq -c '.[2]')
        associations=$(echo "$rt_data" | jq -c '.[3]')
        tags=$(echo "$rt_data" | jq -c '.[4]')
        
        # Skip main route tables (they're managed by VPC)
        local is_main
        is_main=$(echo "$associations" | jq -r '.[] | select(.Main == true) | .Main')
        if [[ "$is_main" == "true" ]]; then
            continue
        fi
        
        # Get route table name from tags
        local rt_name
        rt_name=$(get_tag_value "$tags" "Name")
        if [[ "$rt_name" == "null" || -z "$rt_name" ]]; then
            rt_name="rt-$rt_id"
        fi
        
        if should_include "$rt_name"; then
            log_info "Processing Route Table: $rt_name ($rt_id)"
            
            # Get VPC name for reference
            local vpc_name
            vpc_name=$(aws ec2 describe-vpcs --vpc-ids "$vpc_id" --region "$REGION" --query 'Vpcs[0].Tags[?Key==`Name`].Value | [0]' --output text)
            if [[ "$vpc_name" == "None" || -z "$vpc_name" ]]; then
                vpc_name="$vpc_id"
            fi
            
            # Process routes (exclude local routes)
            local routes_config="[]"
            if [[ "$routes" != "[]" ]]; then
                local route_list="[]"
                while IFS= read -r route; do
                    local destination_cidr gateway_id nat_gateway_id
                    destination_cidr=$(echo "$route" | jq -r '.DestinationCidrBlock // ""')
                    gateway_id=$(echo "$route" | jq -r '.GatewayId // ""')
                    nat_gateway_id=$(echo "$route" | jq -r '.NatGatewayId // ""')
                    
                    # Skip local routes
                    if [[ "$gateway_id" == "local" ]]; then
                        continue
                    fi
                    
                    local route_config=""
                    if [[ -n "$gateway_id" && "$gateway_id" != "null" ]]; then
                        if [[ "$gateway_id" == igw-* ]]; then
                            route_config="{\n          cidr_block   = \"$destination_cidr\"\n          gateway_id   = \"igw-${vpc_name}\"  # Reference to IGW\n          gateway_type = \"igw\"\n        }"
                        else
                            route_config="{\n          cidr_block = \"$destination_cidr\"\n          gateway_id = \"$gateway_id\"\n        }"
                        fi
                    elif [[ -n "$nat_gateway_id" && "$nat_gateway_id" != "null" ]]; then
                        route_config="{\n          cidr_block     = \"$destination_cidr\"\n          nat_gateway_id = \"nat-gw-${nat_gateway_id}\"  # Reference to NAT Gateway\n        }"
                    fi
                    
                    if [[ -n "$route_config" ]]; then
                        if [[ "$route_list" == "[]" ]]; then
                            route_list="[$route_config]"
                        else
                            route_list="${route_list%]}, $route_config]"
                        fi
                    fi
                done < <(echo "$routes" | jq -c '.[]')
                routes_config="$route_list"
            fi
            
            # Sanitize keys
            local key vpc_key
            key=$(sanitize_key "$rt_name")
            vpc_key=$(sanitize_key "$vpc_name")
            
            # Format tags
            local tag_config
            tag_config=$(format_tags "$tags")
            
            # Build route table JSON
            local rt_config
            rt_config=$(cat << EOF
    "$key" = {
      vpc_key = "$vpc_key"  # Reference to VPC: $vpc_name
      routes  = $routes_config
      tags = {
        ImportedBy          = "terraform-script"
        Environment         = "existing"
        OriginalRouteTableId = "$rt_id"
$([ -n "$tag_config" ] && echo "        $tag_config")
      }
    }
EOF
            )
            
            # Process associations
            while IFS= read -r association; do
                local subnet_id association_id
                subnet_id=$(echo "$association" | jq -r '.SubnetId // ""')
                association_id=$(echo "$association" | jq -r '.RouteTableAssociationId // ""')
                
                if [[ -n "$subnet_id" && "$subnet_id" != "null" ]]; then
                    # Get subnet name
                    local subnet_name
                    subnet_name=$(aws ec2 describe-subnets --subnet-ids "$subnet_id" --region "$REGION" --query 'Subnets[0].Tags[?Key==`Name`].Value | [0]' --output text)
                    if [[ "$subnet_name" == "None" || -z "$subnet_name" ]]; then
                        subnet_name="subnet-$subnet_id"
                    fi
                    
                    local subnet_key assoc_key
                    subnet_key=$(sanitize_key "$subnet_name")
                    assoc_key="${subnet_key}-${key}-assoc"
                    
                    local assoc_config
                    assoc_config=$(cat << EOF
    "$assoc_key" = {
      subnet_key      = "$subnet_key"  # Reference to subnet: $subnet_name
      route_table_key = "$key"         # Reference to route table: $rt_name
    }
EOF
                    )
                    
                    if [[ -n "$associations_json" ]]; then
                        associations_json="$associations_json,$assoc_config"
                    else
                        associations_json="$assoc_config"
                    fi
                fi
            done < <(echo "$associations" | jq -c '.[]')
            
            if [[ -n "$route_tables_json" ]]; then
                route_tables_json="$route_tables_json,$rt_config"
            else
                route_tables_json="$rt_config"
            fi
        fi
    done < <(cat "$TEMP_DIR/route_tables.json" | jq -c '.[]')
    
    echo "$route_tables_json|$associations_json"
}

# Generate the complete Terraform configuration
generate_config() {
    log_info "Generating complete Terraform configuration..."
    
    local config
    config=$(cat << 'EOF'
# Generated VPC Configuration
# Generated by terraform-vpc-config script
# Account: ACCOUNT_ID
# Region: REGION
# Generated: $(date)

module "imported_vpc" {
  source = "./modules/vpc"

EOF
    )
    
    # Replace placeholders
    config=$(echo "$config" | sed "s/ACCOUNT_ID/$ACCOUNT_ID/g" | sed "s/REGION/$REGION/g")
    
    # Generate VPCs
    local vpcs_json
    vpcs_json=$(generate_vpcs)
    if [[ -n "$vpcs_json" ]]; then
        config="$config  # VPCs\n  vpcs = {\n$vpcs_json\n  }\n\n"
    fi
    
    # Generate Internet Gateways
    local igws_json
    igws_json=$(generate_internet_gateways)
    if [[ -n "$igws_json" ]]; then
        config="$config  # Internet Gateways\n  internet_gateways = {\n$igws_json\n  }\n\n"
    fi
    
    # Generate Subnets
    local subnets_json
    subnets_json=$(generate_subnets)
    if [[ -n "$subnets_json" ]]; then
        config="$config  # Subnets\n  subnets = {\n$subnets_json\n  }\n\n"
    fi
    
    # Generate NAT Gateways and EIPs
    local nat_eip_result
    nat_eip_result=$(generate_nat_gateways_and_eips)
    local eips_json nat_gws_json
    eips_json=$(echo "$nat_eip_result" | cut -d'|' -f1)
    nat_gws_json=$(echo "$nat_eip_result" | cut -d'|' -f2)
    
    if [[ -n "$eips_json" ]]; then
        config="$config  # Elastic IPs for NAT Gateways\n  elastic_ips = {\n$eips_json\n  }\n\n"
    fi
    
    if [[ -n "$nat_gws_json" ]]; then
        config="$config  # NAT Gateways\n  nat_gateways = {\n$nat_gws_json\n  }\n\n"
    fi
    
    # Generate Route Tables and Associations
    local rt_assoc_result
    rt_assoc_result=$(generate_route_tables)
    local route_tables_json associations_json
    route_tables_json=$(echo "$rt_assoc_result" | cut -d'|' -f1)
    associations_json=$(echo "$rt_assoc_result" | cut -d'|' -f2)
    
    if [[ -n "$route_tables_json" ]]; then
        config="$config  # Route Tables\n  route_tables = {\n$route_tables_json\n  }\n\n"
    fi
    
    if [[ -n "$associations_json" ]]; then
        config="$config  # Route Table Associations\n  route_table_associations = {\n$associations_json\n  }\n\n"
    fi
    
    # Add common tags and close
    config="$config  # Common tags\n  common_tags = {\n    Project     = \"terraform-multi-account-organization\"\n    ManagedBy   = \"terraform\"\n    ImportedBy  = \"script\"\n    Environment = \"existing\"\n    AccountId   = \"$ACCOUNT_ID\"\n    Region      = \"$REGION\"\n  }\n}\n"
    
    echo -e "$config"
}

# Main execution
main() {
    log_info "Starting VPC configuration generation..."
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
        echo "  - VPCs: $(grep -c 'vpcs = {' "$OUTPUT_FILE" || echo 0)"
        echo "  - Subnets: $(grep -c 'subnets = {' "$OUTPUT_FILE" || echo 0)"
        echo "  - Total lines: $(wc -l < "$OUTPUT_FILE")"
        echo "  - Account ID: $ACCOUNT_ID"
        echo "  - Region: $REGION"
        
        log_info "Next steps:"
        echo "  1. Review the generated configuration: $OUTPUT_FILE"
        echo "  2. Adjust resource keys and references as needed"
        echo "  3. Run 'terraform plan' to see what will be imported"
        echo "  4. Use terraform import commands to import resources"
    fi
    
    # Cleanup
    rm -rf "$TEMP_DIR"
    
    log_success "VPC configuration generation completed!"
}

# Run main function
main "$@"
