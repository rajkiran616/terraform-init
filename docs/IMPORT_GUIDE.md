# AWS Resource Import Guide

This guide will help you import existing AWS resources into your Terraform configuration. The process varies depending on the complexity of your existing infrastructure.

## 🎯 Import Strategy Overview

### Phase 1: Discovery and Planning
1. **Resource Discovery** - Identify all existing resources
2. **Dependency Mapping** - Understand resource relationships
3. **Priority Planning** - Decide import order (VPCs → Subnets → Security Groups → Instances)

### Phase 2: Preparation
1. **Generate Configurations** - Create Terraform configs that match existing resources
2. **State Planning** - Decide on state organization (per account, per environment)
3. **Backup Strategy** - Backup existing resources and configurations

### Phase 3: Import Execution
1. **Start with Foundation** - Import VPCs, subnets, security groups first
2. **Add Compute Resources** - Import EC2, RDS, Load Balancers
3. **Import Supporting Services** - S3, IAM roles, Route53

### Phase 4: Validation and Cleanup
1. **Validate State** - Ensure all resources are properly imported
2. **Test Changes** - Verify terraform plan shows no unexpected changes
3. **Documentation** - Update documentation and runbooks

## 🛠️ Tools and Methods

### Method 1: Automated Discovery (Recommended)

Use the built-in resource discovery module:

```bash
# 1. Run resource discovery
cd environments/multi-account
terraform apply

# 2. This generates:
# - import_configs/ACCOUNT_resources.tf (resource definitions)
# - import_scripts/ACCOUNT_import_commands.sh (import commands)
# - IMPORT_PLAN.md (comprehensive import strategy)
```

### Method 2: Manual Discovery

For more control, manually discover resources:

```bash
# List VPCs
aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0]]' --output table

# List Subnets
aws ec2 describe-subnets --query 'Subnets[*].[SubnetId,VpcId,CidrBlock,AvailabilityZone,Tags[?Key==`Name`].Value|[0]]' --output table

# List Security Groups
aws ec2 describe-security-groups --query 'SecurityGroups[*].[GroupId,GroupName,VpcId,Description]' --output table

# List EC2 Instances
aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,Tags[?Key==`Name`].Value|[0]]' --output table
```

### Method 3: Third-Party Tools

Consider using tools like:
- **Terraformer** - Generates Terraform configuration from existing infrastructure
- **Former2** - Browser-based tool for generating Terraform from AWS Console
- **AWS Config** - Export resource configurations

## 📋 Step-by-Step Import Process

### Step 1: Prepare Your Environment

```bash
# Create import workspace
mkdir -p import_workspace
cd import_workspace

# Copy base configuration
cp -r ../environments/dev/* .

# Initialize Terraform
terraform init
```

### Step 2: Generate Resource Configurations

```bash
# Run the discovery process
cd ../environments/multi-account
terraform apply

# Copy generated configs to your workspace
cp import_configs/dev-account_resources.tf ../import_workspace/imported_resources.tf
cp import_scripts/dev-account_import_commands.sh ../import_workspace/
```

### Step 3: Review and Adjust Configurations

Edit `imported_resources.tf` to:
- Fix any syntax errors
- Add missing required arguments
- Set appropriate lifecycle rules
- Add ignore_changes for non-importable attributes

### Step 4: Import Resources

```bash
# Make import script executable
chmod +x dev-account_import_commands.sh

# Run the import (start with a subset for testing)
./dev-account_import_commands.sh

# Or import individual resources
terraform import aws_vpc.main_vpc vpc-12345678
terraform import aws_subnet.public_subnet_1 subnet-12345678
```

### Step 5: Validate Import

```bash
# Check what Terraform thinks needs to change
terraform plan

# If there are unwanted changes, adjust the configuration
# Re-run until terraform plan shows no changes
terraform plan
```

## 🔍 Common Import Scenarios

### Scenario 1: Import a Complete VPC Setup

```bash
# 1. Import VPC
terraform import aws_vpc.main vpc-12345678

# 2. Import Internet Gateway
terraform import aws_internet_gateway.main igw-12345678

# 3. Import Subnets
terraform import aws_subnet.public_1 subnet-12345678
terraform import aws_subnet.private_1 subnet-87654321

# 4. Import Route Tables
terraform import aws_route_table.public rtb-12345678
terraform import aws_route_table.private rtb-87654321

# 5. Import Routes
terraform import aws_route.public_internet rtb-12345678_0.0.0.0/0

# 6. Import Route Table Associations
terraform import aws_route_table_association.public subnet-12345678/rtb-12345678
```

### Scenario 2: Import EC2 with Dependencies

```bash
# 1. Import Security Group first
terraform import aws_security_group.web sg-12345678

# 2. Import Key Pair
terraform import aws_key_pair.deployer my-key-pair

# 3. Import EC2 Instance
terraform import aws_instance.web i-12345678

# 4. Import EBS Volumes (if any)
terraform import aws_ebs_volume.additional vol-12345678

# 5. Import Volume Attachments
terraform import aws_volume_attachment.additional i-12345678:vol-12345678:/dev/sdf
```

### Scenario 3: Import Load Balancer Setup

```bash
# 1. Import ALB
terraform import aws_lb.main arn:aws:elasticloadbalancing:us-east-1:123456789:loadbalancer/app/my-alb/1234567890

# 2. Import Target Group
terraform import aws_lb_target_group.web arn:aws:elasticloadbalancing:us-east-1:123456789:targetgroup/my-targets/1234567890

# 3. Import Listener
terraform import aws_lb_listener.web arn:aws:elasticloadbalancing:us-east-1:123456789:listener/app/my-alb/1234567890/1234567890

# 4. Import Target Attachments
terraform import aws_lb_target_group_attachment.web my-target-group-arn/i-12345678/80
```

## ⚠️ Common Pitfalls and Solutions

### Problem 1: Configuration Drift

**Symptom**: `terraform plan` shows unwanted changes after import

**Solutions**:
```hcl
# Use lifecycle rules to ignore non-critical changes
resource "aws_instance" "example" {
  # ... other configuration ...
  
  lifecycle {
    ignore_changes = [
      ami,                    # AMI can't be changed without replacement
      key_name,              # Key pair can't be changed
      vpc_security_group_ids, # Might be managed elsewhere
    ]
  }
}
```

### Problem 2: Missing Required Arguments

**Symptom**: Terraform plan fails due to missing required arguments

**Solution**: Add required arguments with appropriate values:
```hcl
resource "aws_instance" "example" {
  ami           = "ami-12345678"  # Must match actual AMI
  instance_type = "t3.micro"     # Must match actual type
  # Add other required arguments
}
```

### Problem 3: Resource Dependencies

**Symptom**: Import fails due to missing dependent resources

**Solution**: Import resources in dependency order:
1. VPCs
2. Subnets, Security Groups
3. Load Balancers, RDS Subnet Groups  
4. EC2 Instances, RDS Instances
5. Route53 Records, etc.

### Problem 4: State File Corruption

**Symptom**: Terraform state becomes inconsistent

**Solutions**:
```bash
# Backup state first
cp terraform.tfstate terraform.tfstate.backup

# Remove problematic resource from state
terraform state rm aws_instance.problematic

# Re-import the resource
terraform import aws_instance.problematic i-12345678

# If all else fails, restore from backup
cp terraform.tfstate.backup terraform.tfstate
```

## 🎯 Import Best Practices

### 1. Start Small
- Begin with non-critical environments (dev/staging)
- Import a few resources at a time
- Validate each step before proceeding

### 2. Use Consistent Naming
```hcl
# Good: Consistent, descriptive names
resource "aws_vpc" "main" { }
resource "aws_subnet" "public_1" { }
resource "aws_subnet" "private_1" { }

# Bad: Inconsistent naming
resource "aws_vpc" "vpc1" { }
resource "aws_subnet" "sub_a" { }
resource "aws_subnet" "private_subnet_for_databases" { }
```

### 3. Group Related Resources
```hcl
# Group by function or layer
resource "aws_vpc" "main" { }
resource "aws_internet_gateway" "main" { }
resource "aws_route_table" "main" { }

# Or use modules for reusable components
module "vpc" {
  source = "../../modules/vpc"
  # ...
}
```

### 4. Document Everything
- Keep track of what's been imported
- Document any manual changes needed
- Note resources that can't be imported

### 5. Test Thoroughly
```bash
# Always test before applying to production
terraform plan -out=plan.out
terraform show plan.out  # Review the plan in detail

# Only apply if you're confident
terraform apply plan.out
```

## 🚨 Emergency Procedures

### If Import Goes Wrong

1. **Stop immediately** - Don't make additional changes
2. **Restore state backup** if you have one
3. **Remove problematic resources** from state
4. **Start over** with just the problematic resources

```bash
# Remove resource from state (doesn't delete actual resource)
terraform state rm aws_instance.problematic

# Import it again with correct configuration
terraform import aws_instance.problematic i-12345678
```

### If Resources Get Accidentally Destroyed

1. **Check if resources still exist** in AWS Console
2. **Restore from backup** if resources were actually deleted
3. **Re-import** if resources still exist but were removed from state

## 📊 Import Progress Tracking

Use this checklist to track your import progress:

### Account: _______________

- [ ] **Discovery Phase**
  - [ ] VPCs identified
  - [ ] Subnets mapped
  - [ ] Security groups documented
  - [ ] EC2 instances catalogued
  - [ ] Dependencies mapped

- [ ] **Import Phase**
  - [ ] VPCs imported
  - [ ] Subnets imported  
  - [ ] Security groups imported
  - [ ] Route tables imported
  - [ ] EC2 instances imported
  - [ ] Load balancers imported
  - [ ] RDS instances imported

- [ ] **Validation Phase**
  - [ ] terraform plan shows no changes
  - [ ] All resources accessible
  - [ ] Dependencies working
  - [ ] Documentation updated

## 🔄 Ongoing Management

After successful import:

1. **Regular Planning** - Run `terraform plan` regularly to catch drift
2. **State Maintenance** - Keep state files backed up and versioned
3. **Configuration Updates** - Keep Terraform configs in sync with reality
4. **Team Training** - Ensure team knows how to manage imported resources

Remember: **Importing is just the beginning**. The real value comes from ongoing infrastructure as code management!