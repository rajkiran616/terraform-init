variable "aws_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project/company"
  type        = string
}

variable "owner" {
  description = "Owner/team responsible for the infrastructure"
  type        = string
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "Infrastructure"
}

variable "cross_account_role_name" {
  description = "Name of the cross-account role for Terraform access"
  type        = string
  default     = "TerraformCrossAccountRole"
}

variable "cross_account_external_id" {
  description = "External ID for cross-account role assumption"
  type        = string
  default     = null
}

variable "create_cross_account_roles" {
  description = "Whether to create cross-account roles (only needed once)"
  type        = bool
  default     = false
}

variable "terraform_state_bucket" {
  description = "S3 bucket for Terraform state"
  type        = string
}

variable "terraform_lock_table" {
  description = "DynamoDB table for state locking"
  type        = string
}

variable "excluded_account_ids" {
  description = "List of account IDs to exclude from resource creation"
  type        = list(string)
  default     = []
}

# Network Configuration
variable "base_cidr" {
  description = "Base CIDR block for automatic VPC CIDR allocation"
  type        = string
  default     = "10.0.0.0/8"
}

variable "create_nat_gateway_non_prod" {
  description = "Whether to create NAT gateways in non-production environments"
  type        = bool
  default     = false
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = true
}

# Resource Creation Flags
variable "create_web_tier" {
  description = "Create web tier security groups and resources"
  type        = bool
  default     = true
}

variable "create_app_tier" {
  description = "Create application tier security groups and resources"
  type        = bool
  default     = true
}

variable "create_database_tier" {
  description = "Create database tier security groups and resources"
  type        = bool
  default     = true
}

variable "create_bastion" {
  description = "Create bastion host security group"
  type        = bool
  default     = false
}

variable "create_alb" {
  description = "Create Application Load Balancer"
  type        = bool
  default     = false
}

variable "create_efs" {
  description = "Create EFS security group"
  type        = bool
  default     = false
}

variable "create_route53_zones" {
  description = "Create Route53 private zones"
  type        = bool
  default     = false
}

# Security Configuration
variable "web_ingress_cidrs" {
  description = "CIDR blocks allowed to access web tier"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "bastion_allowed_cidrs" {
  description = "CIDR blocks allowed to access bastion hosts"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "alb_ingress_cidrs" {
  description = "CIDR blocks allowed to access ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "app_port" {
  description = "Application port number"
  type        = number
  default     = 8080
}

# DNS Configuration
variable "private_dns_domain" {
  description = "Private DNS domain name"
  type        = string
  default     = "internal.local"
}

# Standard IAM Roles per Account (no service-linked roles)
variable "standard_iam_roles_per_account" {
  description = "Map of standard IAM roles to create in each account"
  type = map(object({
    description           = string
    trusted_entities     = list(string)  # Services or ARNs that can assume this role
    managed_policy_arns  = list(string)  # AWS managed policies to attach
    inline_policies      = optional(map(string), {})  # Custom inline policies
    max_session_duration = optional(number, 3600)
    tags                 = optional(map(string), {})
  }))
  default = {
    "EC2InstanceRole" = {
      description = "IAM role for EC2 instances"
      trusted_entities = ["ec2.amazonaws.com"]
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
        "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      ]
      inline_policies = {}
      tags = {
        Purpose = "EC2"
        Service = "Compute"
      }
    }
    "ApplicationRole" = {
      description = "IAM role for application workloads"
      trusted_entities = ["ec2.amazonaws.com"]
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
      ]
      inline_policies = {
        "S3Access" = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect = "Allow"
              Action = [
                "s3:GetObject",
                "s3:PutObject"
              ]
              Resource = [
                "arn:aws:s3:::app-data-*/*"
              ]
            }
          ]
        })
      }
      tags = {
        Purpose = "Application"
        Service = "Workload"
      }
    }
    "MonitoringRole" = {
      description = "IAM role for monitoring and logging services"
      trusted_entities = ["ec2.amazonaws.com"]
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
        "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
      ]
      inline_policies = {}
      tags = {
        Purpose = "Monitoring"
        Service = "Observability"
      }
    }
  }
}

# Cross-account trust relationships
variable "cross_account_trust_relationships" {
  description = "Map of cross-account trust relationships to establish"
  type = map(object({
    description      = string
    trusted_accounts = list(string)  # Account IDs that can assume this role
    conditions       = optional(map(any), {})  # Additional assume role conditions
    managed_policy_arns = list(string)
    inline_policies     = optional(map(string), {})
  }))
  default = {
    "CrossAccountReadOnlyRole" = {
      description = "Role for cross-account read-only access"
      trusted_accounts = []  # Will be populated with discovered account IDs
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/ReadOnlyAccess"
      ]
      inline_policies = {}
    }
    "CrossAccountDeveloperRole" = {
      description = "Role for cross-account developer access"
      trusted_accounts = []
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/PowerUserAccess"
      ]
      inline_policies = {
        "DenyDangerousActions" = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect = "Deny"
              Action = [
                "iam:*",
                "organizations:*",
                "account:*"
              ]
              Resource = "*"
            }
          ]
        })
      }
    }
  }
}

# Application-specific IAM roles
variable "application_iam_roles" {
  description = "Application-specific IAM roles to create"
  type = map(object({
    description         = string
    trusted_entities   = list(string)
    managed_policy_arns = list(string)
    inline_policies     = optional(map(string), {})
    create_in_environments = list(string)  # Which environments to create this role in
    tags               = optional(map(string), {})
  }))
  default = {
    "WebServerRole" = {
      description = "Role for web server instances"
      trusted_entities = ["ec2.amazonaws.com"]
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
      ]
      create_in_environments = ["production", "staging", "development"]
      inline_policies = {
        "WebServerPolicy" = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect = "Allow"
              Action = [
                "s3:GetObject"
              ]
              Resource = [
                "arn:aws:s3:::static-assets-*/*"
              ]
            }
          ]
        })
      }
      tags = {
        Purpose = "WebServer"
        Tier = "Web"
      }
    }
    "DatabaseAccessRole" = {
      description = "Role for database access"
      trusted_entities = ["ec2.amazonaws.com"]
      managed_policy_arns = []
      create_in_environments = ["production", "staging"]
      inline_policies = {
        "DatabaseAccess" = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect = "Allow"
              Action = [
                "rds-db:connect"
              ]
              Resource = [
                "arn:aws:rds-db:*:*:dbuser:*/app-user"
              ]
            }
          ]
        })
      }
      tags = {
        Purpose = "Database"
        Tier = "Data"
      }
    }
  }
}

# Environment-specific configuration
variable "environment_configurations" {
  description = "Environment-specific settings"
  type = map(object({
    vpc_cidr_newbits      = number  # CIDR subnet size from base CIDR
    subnet_cidr_newbits   = number  # Subnet size from VPC CIDR
    max_azs              = number   # Maximum AZs to use
    enable_nat_gateway   = bool     # Whether to create NAT gateways
    enable_flow_logs     = bool     # Whether to enable VPC flow logs
    backup_retention_days = number  # Backup retention period
    monitoring_level     = string   # "basic" or "detailed"
  }))
  default = {
    "production" = {
      vpc_cidr_newbits      = 8   # /16 VPCs from /8 base
      subnet_cidr_newbits   = 4   # /20 subnets from /16 VPC
      max_azs              = 3
      enable_nat_gateway   = true
      enable_flow_logs     = true
      backup_retention_days = 30
      monitoring_level     = "detailed"
    }
    "staging" = {
      vpc_cidr_newbits      = 12  # /20 VPCs from /8 base
      subnet_cidr_newbits   = 4   # /24 subnets from /20 VPC
      max_azs              = 2
      enable_nat_gateway   = true
      enable_flow_logs     = true
      backup_retention_days = 7
      monitoring_level     = "basic"
    }
    "development" = {
      vpc_cidr_newbits      = 12  # /20 VPCs from /8 base
      subnet_cidr_newbits   = 4   # /24 subnets from /20 VPC
      max_azs              = 2
      enable_nat_gateway   = false
      enable_flow_logs     = false
      backup_retention_days = 3
      monitoring_level     = "basic"
    }
    "default" = {
      vpc_cidr_newbits      = 8   # /16 VPCs from /8 base
      subnet_cidr_newbits   = 4   # /20 subnets from /16 VPC
      max_azs              = 2
      enable_nat_gateway   = false
      enable_flow_logs     = true
      backup_retention_days = 7
      monitoring_level     = "basic"
    }
  }
}