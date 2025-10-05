# Multi-account AWS provider configuration
# This file provides reusable provider configurations for cross-account access

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Default provider (usually for root account or current account)
provider "aws" {
  alias  = "default"
  region = var.aws_region
  
  default_tags {
    tags = var.default_tags
  }
}

# Root account provider
provider "aws" {
  alias  = "root"
  region = var.aws_region

  assume_role {
    role_arn = var.root_account_role_arn != null ? var.root_account_role_arn : null
  }

  default_tags {
    tags = merge(var.default_tags, {
      Account = "root"
    })
  }
}

# Development account provider
provider "aws" {
  alias  = "dev"
  region = var.aws_region

  assume_role {
    role_arn = var.dev_account_role_arn
  }

  default_tags {
    tags = merge(var.default_tags, {
      Account = "dev"
    })
  }
}

# Staging account provider
provider "aws" {
  alias  = "staging"
  region = var.aws_region

  assume_role {
    role_arn = var.staging_account_role_arn
  }

  default_tags {
    tags = merge(var.default_tags, {
      Account = "staging"
    })
  }
}

# Production account provider
provider "aws" {
  alias  = "prod"
  region = var.aws_region

  assume_role {
    role_arn = var.prod_account_role_arn
  }

  default_tags {
    tags = merge(var.default_tags, {
      Account = "prod"
    })
  }
}

# Additional regional providers (example for multi-region setup)
provider "aws" {
  alias  = "us-west-2"
  region = "us-west-2"
  
  default_tags {
    tags = var.default_tags
  }
}

provider "aws" {
  alias  = "eu-west-1"
  region = "eu-west-1"
  
  default_tags {
    tags = var.default_tags
  }
}