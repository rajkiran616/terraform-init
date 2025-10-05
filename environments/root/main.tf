# Root Account Infrastructure Configuration
# This configuration manages resources in the root/master account

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }

  backend "s3" {
    # Backend configuration will be provided via backend config file
    # or terraform init -backend-config
    encrypt = true
  }
}

# Provider configuration
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = local.common_tags
  }
}

# Local values
locals {
  environment = "root"
  
  common_tags = {
    Environment   = local.environment
    Project       = var.project_name
    ManagedBy     = "Terraform"
    Owner         = var.owner
    CostCenter    = var.cost_center
    LastUpdated   = formatdate("YYYY-MM-DD", timestamp())
  }
}

# IAM Cross-Account Roles
module "cross_account_iam" {
  source = "../../modules/iam"
  
  create_cross_account_role = true
  cross_account_role_name   = "TerraformCrossAccountRole"
  trusted_account_arns = [
    "arn:aws:iam::${var.dev_account_id}:root",
    "arn:aws:iam::${var.staging_account_id}:root",
    "arn:aws:iam::${var.prod_account_id}:root"
  ]
  external_id = var.cross_account_external_id
  
  policy_arns = [
    "arn:aws:iam::aws:policy/PowerUserAccess"
  ]
  
  # Service roles for root account resources
  service_roles = {
    "OrganizationRole" = {
      service     = "organizations.amazonaws.com"
      policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSOrganizationsServiceTrustPolicy"]
    }
    "CloudTrailRole" = {
      service = "cloudtrail.amazonaws.com"
      policy_arns = [
        "arn:aws:iam::aws:policy/service-role/AWSCloudTrailLogsRole"
      ]
    }
  }
  
  tags = local.common_tags
}

# Shared Services VPC (for shared resources like Transit Gateway)
module "shared_vpc" {
  source = "../../modules/vpc"
  
  vpc_name = "${var.project_name}-shared-vpc"
  vpc_cidr = var.shared_vpc_cidr
  
  availability_zones = data.aws_availability_zones.available.names
  
  public_subnet_cidrs  = var.shared_public_subnet_cidrs
  private_subnet_cidrs = var.shared_private_subnet_cidrs
  
  create_igw         = true
  create_nat_gateway = true
  enable_flow_logs   = var.enable_vpc_flow_logs
  
  tags = local.common_tags
}

# Security Groups for shared services
module "shared_security_groups" {
  source = "../../modules/security-groups"
  
  name_prefix = "${var.project_name}-shared"
  vpc_id      = module.shared_vpc.vpc_id
  
  create_web_sg      = false
  create_app_sg      = false
  create_database_sg = false
  create_bastion_sg  = true
  create_alb_sg      = false
  create_efs_sg      = false
  
  bastion_ingress_cidrs = var.bastion_allowed_cidrs
  
  custom_security_groups = {
    "transit-gateway" = {
      description = "Security group for Transit Gateway attachments"
      ingress_rules = [
        {
          from_port   = 0
          to_port     = 65535
          protocol    = "tcp"
          cidr_blocks = [var.shared_vpc_cidr, var.dev_vpc_cidr, var.staging_vpc_cidr, var.prod_vpc_cidr]
          description = "Allow traffic from all connected VPCs"
        }
      ]
      egress_rules = [
        {
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
          description = "All outbound traffic"
        }
      ]
      tags = {
        Purpose = "transit-gateway"
      }
    }
  }
  
  tags = local.common_tags
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# CloudTrail for organization-wide logging
resource "aws_cloudtrail" "organization_trail" {
  count = var.enable_organization_cloudtrail ? 1 : 0
  
  name           = "${var.project_name}-organization-trail"
  s3_bucket_name = aws_s3_bucket.cloudtrail_logs[0].bucket
  
  include_global_service_events = true
  is_multi_region_trail         = true
  is_organization_trail         = true
  enable_logging                = true
  
  event_selector {
    read_write_type                 = "All"
    include_management_events       = true
    exclude_management_event_sources = []
    
    data_resource {
      type   = "AWS::S3::Object"
      values = ["*"]
    }
  }
  
  tags = local.common_tags
}

# S3 bucket for CloudTrail logs
resource "aws_s3_bucket" "cloudtrail_logs" {
  count = var.enable_organization_cloudtrail ? 1 : 0
  
  bucket        = "${var.project_name}-cloudtrail-logs-${random_string.bucket_suffix.result}"
  force_destroy = false
  
  tags = local.common_tags
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket_versioning" "cloudtrail_logs" {
  count = var.enable_organization_cloudtrail ? 1 : 0
  
  bucket = aws_s3_bucket.cloudtrail_logs[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_logs" {
  count = var.enable_organization_cloudtrail ? 1 : 0
  
  bucket = aws_s3_bucket.cloudtrail_logs[0].id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_logs" {
  count = var.enable_organization_cloudtrail ? 1 : 0
  
  bucket = aws_s3_bucket.cloudtrail_logs[0].id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}