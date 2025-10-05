# providers.tf
# Shared provider configurations for multi-account setup

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Default provider configuration
provider "aws" {
  region = var.aws_region
  
  # Assume role for cross-account access
  assume_role {
    role_arn     = var.assume_role_arn
    session_name = "terraform-${var.environment}"
    external_id  = var.external_id
  }

  default_tags {
    tags = {
      Environment   = var.environment
      ManagedBy    = "Terraform"
      Project      = var.project_name
      Owner        = var.owner
      CostCenter   = var.cost_center
    }
  }
}

# Provider for the management account (where state is stored)
provider "aws" {
  alias  = "management"
  region = var.aws_region
  
  # This uses the default AWS CLI credentials for the management account
  # No assume_role block needed here as this is the account where Terraform runs
  
  default_tags {
    tags = {
      Environment   = "management"
      ManagedBy    = "Terraform"
      Project      = var.project_name
      Owner        = var.owner
      CostCenter   = var.cost_center
    }
  }
}

# Optional: Additional provider for logging/audit account
provider "aws" {
  alias  = "audit"
  region = var.aws_region
  
  assume_role {
    role_arn     = var.audit_assume_role_arn
    session_name = "terraform-audit-${var.environment}"
    external_id  = var.external_id
  }

  default_tags {
    tags = {
      Environment   = "audit"
      ManagedBy    = "Terraform"
      Project      = var.project_name
      Owner        = var.owner
      CostCenter   = var.cost_center
    }
  }
}

# Variables for provider configuration
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "assume_role_arn" {
  description = "ARN of the role to assume in the target account"
  type        = string
}

variable "external_id" {
  description = "External ID for assume role (optional but recommended for security)"
  type        = string
  default     = ""
}

variable "audit_assume_role_arn" {
  description = "ARN of the role to assume in the audit account"
  type        = string
  default     = ""
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "multi-account-infrastructure"
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "infrastructure-team"
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "engineering"
}