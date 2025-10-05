# Development Account Infrastructure Configuration

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Backend configuration will be provided via backend config file
    encrypt = true
  }
}

# Provider configuration - assumes role in dev account
provider "aws" {
  region = var.aws_region
  
  assume_role {
    role_arn = "arn:aws:iam::${var.dev_account_id}:role/TerraformCrossAccountRole"
  }
  
  default_tags {
    tags = local.common_tags
  }
}

# Local values
locals {
  environment = "dev"
  
  common_tags = {
    Environment   = local.environment
    Project       = var.project_name
    ManagedBy     = "Terraform"
    Owner         = var.owner
    CostCenter    = var.cost_center
    LastUpdated   = formatdate("YYYY-MM-DD", timestamp())
  }
}

# Main VPC for development environment
module "main_vpc" {
  source = "../../modules/vpc"
  
  vpc_name = "${var.project_name}-${local.environment}-vpc"
  vpc_cidr = var.vpc_cidr
  
  availability_zones = data.aws_availability_zones.available.names
  
  public_subnet_cidrs    = var.public_subnet_cidrs
  private_subnet_cidrs   = var.private_subnet_cidrs
  database_subnet_cidrs  = var.database_subnet_cidrs
  
  create_igw         = true
  create_nat_gateway = var.create_nat_gateway
  enable_flow_logs   = var.enable_vpc_flow_logs
  
  tags = local.common_tags
}

# Security Groups
module "security_groups" {
  source = "../../modules/security-groups"
  
  name_prefix = "${var.project_name}-${local.environment}"
  vpc_id      = module.main_vpc.vpc_id
  
  create_web_sg      = true
  create_app_sg      = true
  create_database_sg = true
  create_bastion_sg  = var.create_bastion
  create_alb_sg      = var.create_alb
  create_efs_sg      = var.create_efs
  
  web_ingress_cidrs     = var.web_ingress_cidrs
  bastion_ingress_cidrs = var.bastion_allowed_cidrs
  alb_ingress_cidrs     = var.alb_ingress_cidrs
  app_port              = var.app_port
  
  tags = local.common_tags
}

# Application Load Balancer (optional)
module "alb" {
  source = "../../modules/alb"
  count  = var.create_alb ? 1 : 0
  
  name            = "${var.project_name}-${local.environment}-alb"
  internal        = false
  security_groups = [module.security_groups.alb_sg_id]
  subnets         = module.main_vpc.public_subnet_ids
  vpc_id          = module.main_vpc.vpc_id
  
  # Target groups
  target_groups = var.alb_target_groups
  
  # SSL Configuration
  certificate_arn         = var.ssl_certificate_arn
  ssl_policy              = var.ssl_policy
  create_http_listener    = true
  default_target_group    = "web"
  
  # Monitoring
  create_cloudwatch_alarms         = var.enable_monitoring
  target_response_time_threshold   = var.target_response_time_threshold
  alarm_actions                   = []
  
  # Access logs
  access_logs_enabled = var.enable_alb_access_logs
  access_logs_bucket  = var.alb_access_logs_bucket
  access_logs_prefix  = "${local.environment}/alb"
  
  tags = local.common_tags
}

# IAM roles for EC2 instances
module "instance_iam" {
  source = "../../modules/iam"
  
  create_cross_account_role = false
  
  service_roles = {
    "WebServerRole" = {
      service = "ec2.amazonaws.com"
      policy_arns = [
        "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
        "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      ]
    }
    "AppServerRole" = {
      service = "ec2.amazonaws.com"
      policy_arns = [
        "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
        "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      ]
    }
  }
  
  tags = local.common_tags
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# Route53 private hosted zone for internal DNS
resource "aws_route53_zone" "private" {
  count = var.create_private_dns_zone ? 1 : 0
  
  name = "${local.environment}.${var.private_dns_domain}"
  
  vpc {
    vpc_id = module.main_vpc.vpc_id
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.environment}.${var.private_dns_domain}"
    Type = "Private"
  })
}

# VPC Endpoints for cost optimization (optional)
resource "aws_vpc_endpoint" "s3" {
  count = var.create_vpc_endpoints ? 1 : 0
  
  vpc_id       = module.main_vpc.vpc_id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  
  route_table_ids = module.main_vpc.private_route_table_ids
  
  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-${local.environment}-s3-endpoint"
    Service = "S3"
  })
}

resource "aws_vpc_endpoint" "ec2" {
  count = var.create_vpc_endpoints ? 1 : 0
  
  vpc_id              = module.main_vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ec2"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.main_vpc.private_subnet_ids
  security_group_ids  = [module.security_groups.app_sg_id]
  
  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-${local.environment}-ec2-endpoint"
    Service = "EC2"
  })
}