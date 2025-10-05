# Multi-Account AWS Infrastructure with Terraform

This repository provides a comprehensive Terraform setup for managing AWS resources across multiple accounts using AWS Organizations. It's designed to introduce Terraform for managing **new resource creation** going forward, while working alongside existing manually created resources.

## 🏗️ Architecture Overview

```
Root Account (Master)
├── Shared Services (Transit Gateway, DNS, Logging)
├── Development Account(s)
├── Staging Account(s)
└── Production Account(s)
```

## 📁 Directory Structure

```
terraform-aws-infrastructure/
├── environments/           # Environment-specific configurations
│   ├── root/              # Root/Master account resources
│   ├── dev/               # Development environment
│   ├── staging/           # Staging environment
│   ├── prod/              # Production environment
│   └── multi-account/     # Dynamic multi-account management
├── modules/               # Reusable Terraform modules
│   ├── account-discovery/ # Auto-discover AWS Organization accounts
│   ├── iam/              # IAM roles, policies, users
│   ├── vpc/              # VPC, subnets, routing
│   ├── security-groups/  # Security group management
│   ├── alb/              # Application Load Balancer
│   ├── ec2/              # EC2 instances
│   ├── efs/              # Elastic File System
│   ├── ebs/              # Elastic Block Store
│   ├── transit-gateway/  # Transit Gateway for connectivity
│   ├── route53/          # DNS management
│   └── peering/          # VPC peering connections
├── shared/               # Shared configurations
│   ├── backend/          # Terraform state backend setup
│   └── providers/        # Provider configurations
├── scripts/              # Utility scripts
└── docs/                 # Additional documentation
```

## 🚀 Getting Started

### Prerequisites

1. **AWS CLI configured** with appropriate credentials
2. **Terraform >= 1.0** installed
3. **AWS Organizations** set up with multiple accounts
4. **Cross-account roles** created (we'll help you set these up)

### Step 1: Set Up Backend Infrastructure

First, create the S3 bucket and DynamoDB table for Terraform state management:

```bash
cd shared/backend

# Create terraform.tfvars
cat > terraform.tfvars <<EOF
company_name = "your-company"
aws_region   = "us-east-1"
EOF

# Initialize and apply
terraform init
terraform apply
```

### Step 2: Set Up Cross-Account Roles (One-time setup)

Create cross-account roles in each account for Terraform access:

```bash
cd environments/multi-account

# Create terraform.tfvars
cat > terraform.tfvars <<EOF
project_name              = "your-project"
owner                    = "infrastructure-team"
terraform_state_bucket   = "terraform-state-your-company-12345678"
terraform_lock_table     = "terraform-state-lock-your-company"
create_cross_account_roles = true
EOF

# This will discover accounts and create roles
terraform init -backend-config="backend.hcl"
terraform apply
```

### Step 3: Configure Backend for Each Environment

Create backend configuration files:

```bash
# For each environment, create a backend config
cat > backend-dev.hcl <<EOF
bucket         = "terraform-state-your-company-12345678"
key           = "dev/terraform.tfstate"
region        = "us-east-1"
dynamodb_table = "terraform-state-lock-your-company"
encrypt       = true
EOF
```

### Step 4: Deploy Infrastructure to Accounts

```bash
cd environments/multi-account

# Initialize with backend
terraform init -backend-config="backend-multi-account.hcl"

# Plan and apply
terraform plan
terraform apply
```

## 🔧 Key Features

### Dynamic Account Discovery

The setup automatically discovers all accounts in your AWS Organization and categorizes them based on:

- **Account naming patterns** (e.g., `company-env-purpose`)
- **Account tags** (Environment, Purpose, AccountType)
- **Account relationships** (master vs member accounts)

### Automatic CIDR Allocation

VPC CIDRs are automatically allocated from a base CIDR block to avoid conflicts:

```hcl
# Automatically assigns non-overlapping CIDRs
vpc_cidrs = {
  for i, id in keys(deployment_accounts) : id => cidrsubnet(var.base_cidr, 8, i + 1)
}
```

### Environment-Aware Configuration

Different environments get different resource configurations:

- **Production**: High availability, monitoring, backups
- **Staging**: Moderate resources, basic monitoring
- **Development**: Minimal resources, cost-optimized

### IAM Role Management

Standard IAM roles are created without requiring service-linked role permissions:

```hcl
standard_iam_roles_per_account = {
  "EC2InstanceRole" = {
    description = "IAM role for EC2 instances"
    trusted_entities = ["ec2.amazonaws.com"]
    managed_policy_arns = [
      "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
    ]
  }
}
```

## 📝 Configuration Examples

### Basic Multi-Account Setup

```hcl
# terraform.tfvars
project_name = "mycompany"
owner        = "platform-team"
aws_region   = "us-east-1"

# Network configuration
base_cidr = "10.0.0.0/8"
create_nat_gateway_non_prod = false

# Resource flags
create_web_tier      = true
create_app_tier      = true
create_database_tier = true
create_alb          = false  # Enable when needed

# Security
web_ingress_cidrs     = ["0.0.0.0/0"]
bastion_allowed_cidrs = ["203.0.113.0/24"]  # Your office IP
```

### Custom Application Roles

```hcl
application_iam_roles = {
  "WebAppRole" = {
    description = "Role for web application servers"
    trusted_entities = ["ec2.amazonaws.com"]
    managed_policy_arns = [
      "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
    ]
    create_in_environments = ["production", "staging"]
    inline_policies = {
      "S3Access" = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = ["s3:GetObject", "s3:PutObject"]
            Resource = ["arn:aws:s3:::app-assets-*/*"]
          }
        ]
      })
    }
  }
}
```

## 🔒 Security Best Practices

### Cross-Account Access

- Uses assume role for cross-account access
- External ID for additional security
- Least privilege IAM policies
- Regular credential rotation

### Network Security

- Private subnets by default
- NAT Gateways for outbound internet access
- Security groups with minimal required access
- VPC Flow Logs for monitoring

### Resource Tagging

All resources are automatically tagged with:
- `Environment`
- `Project`
- `ManagedBy = "Terraform"`
- `Owner`
- `CostCenter`
- `LastUpdated`

## 🛠️ Managing Existing Resources

Since you have existing resources, this setup is designed to:

1. **Coexist** with existing manually created resources
2. **Gradually migrate** management to Terraform
3. **Avoid conflicts** through careful resource naming and placement

### Import Strategy (Future)

When ready to import existing resources:

1. Use `terraform import` for individual resources
2. Use tools like `terraformer` for bulk imports
3. Gradually bring resources under Terraform management

## 📊 Monitoring and Compliance

### CloudWatch Integration

- VPC Flow Logs
- CloudTrail logging
- Custom CloudWatch alarms
- Cost monitoring tags

### Compliance Features

- Encryption at rest and in transit
- Network isolation
- Access logging
- Regular security assessments

## 🚨 Troubleshooting

### Common Issues

1. **Permission Denied**
   ```bash
   # Ensure cross-account roles exist and are assumable
   aws sts assume-role --role-arn arn:aws:iam::ACCOUNT:role/TerraformCrossAccountRole --role-session-name test
   ```

2. **State Lock Issues**
   ```bash
   # Force unlock if needed (use carefully)
   terraform force-unlock LOCK_ID
   ```

3. **CIDR Conflicts**
   ```bash
   # Check existing VPC CIDRs before deployment
   aws ec2 describe-vpcs --query 'Vpcs[].CidrBlock'
   ```

## 📚 Additional Resources

- [AWS Organizations Best Practices](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_best-practices.html)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Multi-Account Strategy](https://aws.amazon.com/organizations/getting-started/best-practices/)

## 🤝 Contributing

1. Follow existing module structure
2. Include comprehensive variable descriptions
3. Add appropriate outputs
4. Update documentation
5. Test in non-production environments first

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.