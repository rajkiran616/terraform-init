#!/bin/bash

# Practical AWS Resource Import Script
# This script helps you import existing AWS resources into Terraform

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        exit 1
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured"
        exit 1
    fi
    
    # Check jq for JSON parsing
    if ! command -v jq &> /dev/null; then
        print_warning "jq is not installed. Some features may not work properly"
    fi
    
    print_success "All prerequisites satisfied"
}

# Function to discover resources in current account
discover_resources() {
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    local region=${AWS_DEFAULT_REGION:-us-east-1}
    
    print_header "Discovering Resources in Account $account_id"
    
    echo "Scanning region: $region"
    
    # Discover VPCs
    print_info "Discovering VPCs..."
    aws ec2 describe-vpcs --region $region --query 'Vpcs[*].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0]]' --output table
    
    # Discover Subnets
    print_info "Discovering Subnets..."
    aws ec2 describe-subnets --region $region --query 'Subnets[*].[SubnetId,VpcId,CidrBlock,AvailabilityZone,MapPublicIpOnLaunch,Tags[?Key==`Name`].Value|[0]]' --output table
    
    # Discover Security Groups
    print_info "Discovering Security Groups..."
    aws ec2 describe-security-groups --region $region --query 'SecurityGroups[?GroupName!=`default`].[GroupId,GroupName,VpcId,Description]' --output table
    
    # Discover EC2 Instances
    print_info "Discovering EC2 Instances..."
    aws ec2 describe-instances --region $region --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,VpcId,SubnetId,Tags[?Key==`Name`].Value|[0]]' --output table
    
    # Discover Load Balancers
    print_info "Discovering Load Balancers..."
    aws elbv2 describe-load-balancers --region $region --query 'LoadBalancers[*].[LoadBalancerArn,LoadBalancerName,Type,State.Code,VpcId]' --output table 2>/dev/null || echo "No ALBs found or insufficient permissions"
    
    # Discover RDS Instances
    print_info "Discovering RDS Instances..."
    aws rds describe-db-instances --region $region --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceClass,Engine,DBInstanceStatus,VpcId]' --output table 2>/dev/null || echo "No RDS instances found or insufficient permissions"
}

# Function to generate import commands for a specific resource type
generate_import_commands() {
    local resource_type="$1"
    local output_file="$2"
    local region=${AWS_DEFAULT_REGION:-us-east-1}
    
    case $resource_type in
        "vpc")
            print_info "Generating VPC import commands..."
            cat > $output_file << 'EOF'
#!/bin/bash
# VPC Import Commands
set -e

# Get VPC IDs
VPC_IDS=$(aws ec2 describe-vpcs --query 'Vpcs[*].VpcId' --output text)

for vpc_id in $VPC_IDS; do
    vpc_name=$(aws ec2 describe-vpcs --vpc-ids $vpc_id --query 'Vpcs[0].Tags[?Key==`Name`].Value|[0]' --output text)
    safe_name=$(echo "${vpc_name:-vpc}" | sed 's/[^a-zA-Z0-9]/_/g' | tr '[:upper:]' '[:lower:]')
    
    echo "Importing VPC: $vpc_id as aws_vpc.${safe_name}_${vpc_id//-/_}"
    terraform import "aws_vpc.${safe_name}_${vpc_id//-/_}" "$vpc_id" || echo "Failed to import $vpc_id"
done
EOF
            ;;
        
        "subnet")
            print_info "Generating Subnet import commands..."
            cat > $output_file << 'EOF'
#!/bin/bash
# Subnet Import Commands  
set -e

# Get Subnet IDs
SUBNET_IDS=$(aws ec2 describe-subnets --query 'Subnets[*].SubnetId' --output text)

for subnet_id in $SUBNET_IDS; do
    subnet_info=$(aws ec2 describe-subnets --subnet-ids $subnet_id --query 'Subnets[0].[Tags[?Key==`Name`].Value|[0],AvailabilityZone,MapPublicIpOnLaunch]' --output text)
    subnet_name=$(echo $subnet_info | cut -f1)
    az=$(echo $subnet_info | cut -f2)
    is_public=$(echo $subnet_info | cut -f3)
    
    type_prefix="private"
    if [ "$is_public" = "True" ]; then
        type_prefix="public"
    fi
    
    safe_name=$(echo "${subnet_name:-subnet}" | sed 's/[^a-zA-Z0-9]/_/g' | tr '[:upper:]' '[:lower:]')
    
    echo "Importing Subnet: $subnet_id as aws_subnet.${type_prefix}_${safe_name}_${subnet_id//-/_}"
    terraform import "aws_subnet.${type_prefix}_${safe_name}_${subnet_id//-/_}" "$subnet_id" || echo "Failed to import $subnet_id"
done
EOF
            ;;
            
        "security_group")
            print_info "Generating Security Group import commands..."
            cat > $output_file << 'EOF'
#!/bin/bash
# Security Group Import Commands
set -e

# Get Security Group IDs (excluding default)
SG_IDS=$(aws ec2 describe-security-groups --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text)

for sg_id in $SG_IDS; do
    sg_name=$(aws ec2 describe-security-groups --group-ids $sg_id --query 'SecurityGroups[0].GroupName' --output text)
    safe_name=$(echo "$sg_name" | sed 's/[^a-zA-Z0-9]/_/g' | tr '[:upper:]' '[:lower:]')
    
    echo "Importing Security Group: $sg_id as aws_security_group.${safe_name}_${sg_id//-/_}"
    terraform import "aws_security_group.${safe_name}_${sg_id//-/_}" "$sg_id" || echo "Failed to import $sg_id"
done
EOF
            ;;
            
        "ec2")
            print_info "Generating EC2 import commands..."
            cat > $output_file << 'EOF'
#!/bin/bash
# EC2 Instance Import Commands
set -e

# Get EC2 Instance IDs (running and stopped only)
INSTANCE_IDS=$(aws ec2 describe-instances --filters "Name=instance-state-name,Values=running,stopped" --query 'Reservations[*].Instances[*].InstanceId' --output text)

for instance_id in $INSTANCE_IDS; do
    instance_name=$(aws ec2 describe-instances --instance-ids $instance_id --query 'Reservations[0].Instances[0].Tags[?Key==`Name`].Value|[0]' --output text)
    safe_name=$(echo "${instance_name:-instance}" | sed 's/[^a-zA-Z0-9]/_/g' | tr '[:upper:]' '[:lower:]')
    
    echo "Importing EC2 Instance: $instance_id as aws_instance.${safe_name}_${instance_id//-/_}"
    terraform import "aws_instance.${safe_name}_${instance_id//-/_}" "$instance_id" || echo "Failed to import $instance_id"
done
EOF
            ;;
    esac
    
    chmod +x $output_file
    print_success "Generated import script: $output_file"
}

# Function to generate basic resource configurations
generate_terraform_config() {
    local resource_type="$1"
    local output_file="$2"
    local region=${AWS_DEFAULT_REGION:-us-east-1}
    
    print_info "Generating Terraform configuration for $resource_type..."
    
    case $resource_type in
        "vpc")
            cat > $output_file << EOF
# Generated VPC configurations
# Review and adjust before applying

$(aws ec2 describe-vpcs --region $region --query 'Vpcs[*]' --output json | jq -r '.[] | 
"resource \"aws_vpc\" \"" + (.Tags[]? | select(.Key=="Name") | .Value | gsub("[^a-zA-Z0-9]"; "_") | ascii_downcase) + "_" + (.VpcId | gsub("-"; "_")) + "\" {
  cidr_block           = \"" + .CidrBlock + "\"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {" + (if (.Tags | length) > 0 then (.Tags | map("    " + .Key + " = \"" + .Value + "\"") | join("\n")) else "    Name = \"imported-vpc\"" end) + "
  }
  
  lifecycle {
    ignore_changes = [cidr_block]
  }
}
"')
EOF
            ;;
            
        "subnet")
            # This is a simplified version - full implementation would be more complex
            echo "# Subnet configurations require VPC references" > $output_file
            echo "# Please use the automated discovery module for complete subnet configs" >> $output_file
            ;;
    esac
    
    print_success "Generated Terraform config: $output_file"
}

# Interactive mode function
interactive_import() {
    print_header "Interactive Import Mode"
    
    echo "What would you like to import?"
    echo "1. VPCs"
    echo "2. Subnets"
    echo "3. Security Groups" 
    echo "4. EC2 Instances"
    echo "5. All of the above"
    echo "6. Custom resource ID"
    
    read -p "Select option (1-6): " choice
    
    case $choice in
        1)
            generate_import_commands "vpc" "import_vpcs.sh"
            generate_terraform_config "vpc" "vpc_configs.tf"
            print_info "Run ./import_vpcs.sh to import VPCs"
            ;;
        2)
            generate_import_commands "subnet" "import_subnets.sh"
            print_info "Run ./import_subnets.sh to import Subnets"
            ;;
        3)
            generate_import_commands "security_group" "import_security_groups.sh"
            print_info "Run ./import_security_groups.sh to import Security Groups"
            ;;
        4)
            generate_import_commands "ec2" "import_ec2.sh"
            print_info "Run ./import_ec2.sh to import EC2 Instances"
            ;;
        5)
            generate_import_commands "vpc" "import_vpcs.sh"
            generate_import_commands "subnet" "import_subnets.sh"
            generate_import_commands "security_group" "import_security_groups.sh"
            generate_import_commands "ec2" "import_ec2.sh"
            generate_terraform_config "vpc" "vpc_configs.tf"
            
            cat > import_all.sh << 'EOF'
#!/bin/bash
echo "Importing all resources..."
echo "Step 1: Importing VPCs..."
./import_vpcs.sh

echo "Step 2: Importing Subnets..."
./import_subnets.sh

echo "Step 3: Importing Security Groups..."
./import_security_groups.sh

echo "Step 4: Importing EC2 Instances..."
./import_ec2.sh

echo "Import process completed!"
EOF
            chmod +x import_all.sh
            print_success "Created import_all.sh - run this to import everything"
            ;;
        6)
            read -p "Enter resource type (e.g., aws_vpc): " resource_type
            read -p "Enter resource name: " resource_name  
            read -p "Enter resource ID: " resource_id
            
            echo "terraform import \"$resource_type.$resource_name\" \"$resource_id\""
            read -p "Run this command? (y/N): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                terraform import "$resource_type.$resource_name" "$resource_id"
            fi
            ;;
        *)
            print_error "Invalid option"
            exit 1
            ;;
    esac
}

# Main function
main() {
    print_header "AWS Resource Import Tool"
    
    if [ $# -eq 0 ]; then
        # No arguments - show help
        echo "Usage: $0 [discover|interactive|help]"
        echo ""
        echo "Commands:"
        echo "  discover     - Discover existing resources in current account" 
        echo "  interactive  - Interactive import wizard"
        echo "  help         - Show this help"
        echo ""
        echo "Examples:"
        echo "  $0 discover                    # List all discoverable resources"
        echo "  $0 interactive                 # Start interactive import wizard"
        echo ""
        exit 0
    fi
    
    check_prerequisites
    
    case $1 in
        "discover")
            discover_resources
            ;;
        "interactive")
            interactive_import
            ;;
        "help")
            echo "AWS Resource Import Tool Help"
            echo ""
            echo "This tool helps you import existing AWS resources into Terraform."
            echo "It can discover resources and generate import commands automatically."
            echo ""
            echo "Before importing:"
            echo "1. Make sure you have Terraform configurations that match your resources"
            echo "2. Back up your Terraform state file"
            echo "3. Test imports in a development environment first"
            echo ""
            echo "After importing:"
            echo "1. Run 'terraform plan' to check for configuration drift"
            echo "2. Adjust configurations to eliminate unwanted changes"
            echo "3. Re-run 'terraform plan' until no changes are shown"
            ;;
        *)
            print_error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"