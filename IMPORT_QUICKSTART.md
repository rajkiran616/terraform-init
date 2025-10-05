# 🚀 Import Quickstart Guide

This is a quick reference for importing existing AWS resources into your Terraform setup.

## 🎯 Quick Commands

### Discover What You Have
```bash
# See all resources in current AWS account
./scripts/import-resources.sh discover

# Or manually check specific resources
aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0]]' --output table
aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0]]' --output table
```

### Start Import Process
```bash
# Interactive wizard (recommended for beginners)
./scripts/import-resources.sh interactive

# Or use the comprehensive discovery (for advanced users)
cd environments/multi-account
terraform apply  # This generates import scripts and configs
```

## 📋 Import Order (Important!)

Always import in this order to respect dependencies:

1. **VPCs** → 2. **Subnets** → 3. **Security Groups** → 4. **EC2 Instances** → 5. **Load Balancers**

## 🛠️ Step-by-Step Example

### Example: Import a VPC and EC2 Instance

```bash
# 1. First, create a workspace
mkdir import_test && cd import_test

# 2. Create a basic Terraform file
cat > main.tf << 'EOF'
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# VPC Resource (replace with your actual values)
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"  # Match your actual CIDR
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "main-vpc"  # Match your actual name
  }
  
  lifecycle {
    ignore_changes = [cidr_block]
  }
}

# EC2 Instance Resource (replace with your actual values)  
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1d0"  # Match your actual AMI
  instance_type = "t2.micro"               # Match your actual type
  subnet_id     = "subnet-12345678"        # Match your actual subnet
  
  tags = {
    Name = "web-server"  # Match your actual name
  }
  
  lifecycle {
    ignore_changes = [ami, subnet_id, key_name, vpc_security_group_ids]
  }
}
EOF

# 3. Initialize Terraform
terraform init

# 4. Import the resources (replace with your actual IDs)
terraform import aws_vpc.main vpc-12345678
terraform import aws_instance.web i-12345678

# 5. Check for configuration drift
terraform plan

# 6. If there are changes, adjust main.tf and repeat step 5
# 7. Once plan shows no changes, you're done!
```

## 🔍 Common Resource Import Commands

### VPC Resources
```bash
# VPC
terraform import aws_vpc.main vpc-12345678

# Subnets
terraform import aws_subnet.public subnet-12345678
terraform import aws_subnet.private subnet-87654321

# Internet Gateway
terraform import aws_internet_gateway.main igw-12345678

# Route Tables
terraform import aws_route_table.public rtb-12345678

# Routes
terraform import aws_route.public_internet rtb-12345678_0.0.0.0/0
```

### Compute Resources
```bash
# EC2 Instances
terraform import aws_instance.web i-12345678

# Security Groups
terraform import aws_security_group.web sg-12345678

# Key Pairs
terraform import aws_key_pair.deployer my-key-name
```

### Load Balancers
```bash
# Application Load Balancer
terraform import aws_lb.main arn:aws:elasticloadbalancing:us-east-1:123456789:loadbalancer/app/my-alb/1234567890

# Target Group
terraform import aws_lb_target_group.web arn:aws:elasticloadbalancing:us-east-1:123456789:targetgroup/my-targets/1234567890

# Listener
terraform import aws_lb_listener.web arn:aws:elasticloadbalancing:us-east-1:123456789:listener/app/my-alb/1234567890/1234567890
```

## ⚠️ Quick Troubleshooting

### Problem: "terraform plan" shows unwanted changes
**Solution**: Add lifecycle ignore_changes:
```hcl
resource "aws_instance" "example" {
  # ... your config ...
  
  lifecycle {
    ignore_changes = [
      ami,           # Can't change without replacement
      subnet_id,     # Can't change without replacement
      key_name,      # Can't change
    ]
  }
}
```

### Problem: Import fails with "resource already exists"
**Solution**: Remove from state and re-import:
```bash
terraform state rm aws_instance.web
terraform import aws_instance.web i-12345678
```

### Problem: Don't know the exact resource ID
**Solution**: Use AWS CLI to find it:
```bash
# Find VPC ID by name
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=MyVPC" --query 'Vpcs[0].VpcId' --output text

# Find instance ID by name  
aws ec2 describe-instances --filters "Name=tag:Name,Values=MyServer" --query 'Reservations[0].Instances[0].InstanceId' --output text
```

## 💡 Pro Tips

### 1. Start Small
Import one resource at a time, validate with `terraform plan`, then move to the next.

### 2. Use Consistent Names
```hcl
# Good
resource "aws_vpc" "main" { }
resource "aws_subnet" "public_1" { }
resource "aws_subnet" "private_1" { }

# Bad  
resource "aws_vpc" "vpc1" { }
resource "aws_subnet" "sub_a" { }
```

### 3. Always Backup State
```bash
cp terraform.tfstate terraform.tfstate.backup
```

### 4. Test First
Always test imports in dev/staging before touching production.

### 5. Use ignore_changes Liberally
For attributes that don't matter or can't be changed:
```hcl
lifecycle {
  ignore_changes = [ami, key_name, user_data]
}
```

## 🚨 Emergency Recovery

### If Something Goes Wrong:
```bash
# 1. Stop immediately
# 2. Restore state backup
cp terraform.tfstate.backup terraform.tfstate

# 3. Or remove problematic resource from state
terraform state rm aws_instance.problematic

# 4. Start over with just that resource
terraform import aws_instance.problematic i-12345678
```

## 📞 Need Help?

1. **Check the full guide**: `docs/IMPORT_GUIDE.md`
2. **Use discovery tools**: `./scripts/import-resources.sh discover`  
3. **Review resource docs**: [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

Remember: **Importing is iterative**. Don't expect it to be perfect on the first try! 🎯