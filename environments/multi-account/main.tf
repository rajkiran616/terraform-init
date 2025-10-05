# Dynamic Multi-Account Infrastructure Configuration
# This configuration dynamically discovers accounts and creates resources across all of them

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

# Root provider (for organization discovery)
provider "aws" {
  alias  = "root"
  region = var.aws_region
  
  default_tags {
    tags = local.common_tags
  }
}

# Dynamic provider configurations for each discovered account
# This generates providers for all discovered accounts
locals {
  # Discover accounts first
  account_discovery = module.account_discovery
  
  # Create provider configurations for each active account
  account_providers = {
    for id, acc in local.account_discovery.active_accounts : acc.name => {
      account_id = id
      role_arn   = "arn:aws:iam::${id}:role/${var.cross_account_role_name}"
      alias      = replace(lower(acc.name), "-", "_")
      environment = try(
        lower(acc.tags["Environment"]),
        length(split("-", acc.name)) >= 2 ? lower(split("-", acc.name)[1]) : "unknown"
      )
    }
  }
}

# Account Discovery Module
module "account_discovery" {
  source = "../../modules/account-discovery"
  
  providers = {
    aws = aws.root
  }
  
  aws_region                   = var.aws_region
  cross_account_role_name      = var.cross_account_role_name
  cross_account_external_id    = var.cross_account_external_id
  create_cross_account_roles   = var.create_cross_account_roles
  terraform_state_bucket       = var.terraform_state_bucket
  terraform_lock_table         = var.terraform_lock_table
  default_tags                 = local.common_tags
  excluded_account_ids         = var.excluded_account_ids
}

# Local values
locals {
  common_tags = {
    Project       = var.project_name
    ManagedBy     = "Terraform"
    Owner         = var.owner
    CostCenter    = var.cost_center
    LastUpdated   = formatdate("YYYY-MM-DD", timestamp())
    Configuration = "multi-account"
  }
  
  # Filter accounts for workload deployment
  deployment_accounts = {
    for id, acc in module.account_discovery.account_environments : id => acc
    if !contains(["master"], acc.account_type) && !contains(var.excluded_account_ids, id)
  }
  
  # VPC CIDR allocation - automatically assign CIDR blocks
  vpc_cidrs = {
    for i, id in keys(local.deployment_accounts) : id => cidrsubnet(var.base_cidr, 8, i + 1)
  }
}

# Create VPCs in each workload account dynamically
module "account_vpcs" {
  source = "../../modules/vpc"
  
  for_each = local.deployment_accounts
  
  providers = {
    aws = aws.account_${replace(lower(each.value.name), "-", "_")}
  }
  
  vpc_name = "${var.project_name}-${each.value.environment}-vpc"
  vpc_cidr = local.vpc_cidrs[each.key]
  
  availability_zones = data.aws_availability_zones.account_azs[each.key].names
  
  # Automatically calculate subnet CIDRs
  public_subnet_cidrs = [
    for i in range(min(3, length(data.aws_availability_zones.account_azs[each.key].names))) :
    cidrsubnet(local.vpc_cidrs[each.key], 4, i)
  ]
  
  private_subnet_cidrs = [
    for i in range(min(3, length(data.aws_availability_zones.account_azs[each.key].names))) :
    cidrsubnet(local.vpc_cidrs[each.key], 4, i + 3)
  ]
  
  database_subnet_cidrs = [
    for i in range(min(3, length(data.aws_availability_zones.account_azs[each.key].names))) :
    cidrsubnet(local.vpc_cidrs[each.key], 4, i + 6)
  ]
  
  create_igw         = true
  create_nat_gateway = contains(["prod", "production"], each.value.environment) ? true : var.create_nat_gateway_non_prod
  enable_flow_logs   = var.enable_vpc_flow_logs
  
  tags = merge(local.common_tags, {
    Environment = each.value.environment
    AccountId   = each.key
    AccountName = each.value.name
  })
}

# Create security groups in each account
module "account_security_groups" {
  source = "../../modules/security-groups"
  
  for_each = local.deployment_accounts
  
  providers = {
    aws = aws.account_${replace(lower(each.value.name), "-", "_")}
  }
  
  name_prefix = "${var.project_name}-${each.value.environment}"
  vpc_id      = module.account_vpcs[each.key].vpc_id
  
  create_web_sg      = var.create_web_tier
  create_app_sg      = var.create_app_tier
  create_database_sg = var.create_database_tier
  create_bastion_sg  = var.create_bastion
  create_alb_sg      = var.create_alb
  create_efs_sg      = var.create_efs
  
  web_ingress_cidrs     = var.web_ingress_cidrs
  bastion_ingress_cidrs = var.bastion_allowed_cidrs
  alb_ingress_cidrs     = var.alb_ingress_cidrs
  app_port              = var.app_port
  
  tags = merge(local.common_tags, {
    Environment = each.value.environment
    AccountId   = each.key
    AccountName = each.value.name
  })
}

# Create IAM roles in each account
module "account_iam_roles" {
  source = "../../modules/iam"
  
  for_each = local.deployment_accounts
  
  providers = {
    aws = aws.account_${replace(lower(each.value.name), "-", "_")}
  }
  
  create_cross_account_role = false
  
  service_roles = var.service_roles_per_account
  
  tags = merge(local.common_tags, {
    Environment = each.value.environment
    AccountId   = each.key
    AccountName = each.value.name
  })
}

# Data sources for each account
data "aws_availability_zones" "account_azs" {
  for_each = local.deployment_accounts
  
  providers = {
    aws = aws.account_${replace(lower(each.value.name), "-", "_")}
  }
  
  state = "available"
}

# Generate dynamic provider configurations file
resource "local_file" "dynamic_providers" {
  filename = "${path.root}/generated_providers.tf"
  
  content = templatefile("${path.module}/templates/providers.tftpl", {
    accounts    = local.account_providers
    aws_region  = var.aws_region
    common_tags = local.common_tags
  })
}

# Create Route53 private zones for cross-account DNS resolution
module "route53_zones" {
  source = "../../modules/route53"
  
  for_each = var.create_route53_zones ? local.deployment_accounts : {}
  
  providers = {
    aws = aws.account_${replace(lower(each.value.name), "-", "_")}
  }
  
  zone_name = "${each.value.environment}.${var.private_dns_domain}"
  vpc_id    = module.account_vpcs[each.key].vpc_id
  
  tags = merge(local.common_tags, {
    Environment = each.value.environment
    AccountId   = each.key
    AccountName = each.value.name
  })
}

# Output discovered accounts and configurations
output "discovered_accounts" {
  description = "All discovered accounts and their configurations"
  value       = module.account_discovery.account_environments
}

output "deployment_accounts" {
  description = "Accounts selected for resource deployment"
  value       = local.deployment_accounts
}

output "vpc_configurations" {
  description = "VPC configurations for each account"
  value = {
    for id, acc in local.deployment_accounts : id => {
      account_name = acc.name
      environment  = acc.environment
      vpc_id       = module.account_vpcs[id].vpc_id
      vpc_cidr     = local.vpc_cidrs[id]
    }
  }
}

output "backend_configurations" {
  description = "Backend configurations for each environment"
  value       = module.account_discovery.backend_configs
}