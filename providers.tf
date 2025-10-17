# Terraform and Provider Requirements
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # Backend configuration for remote state
  backend "s3" {
    bucket  = "your-terraform-state-bucket"  # Change this to your bucket name
    key     = "iam-management/terraform.tfstate"
    region  = "us-east-1"  # Change this to your preferred region
    encrypt = true
    
    # S3 native state locking (requires versioning enabled on bucket)
    # No DynamoDB table required
  }
}

# Default provider (used for organization-level operations)
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      ManagedBy = "terraform"
      Project   = "iam-management"
    }
  }
}

# Development Account Provider
provider "aws" {
  alias  = "dev"
  region = "us-west-2"
  
  assume_role {
    role_arn = "arn:aws:iam::345678901234:role/DevelopmentAccountAccessRole"
  }
  
  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Project     = "iam-management"
      Environment = "dev"
      Account     = "development"
      AccountId   = "345678901234"
    }
  }
}

# QA Account Provider
provider "aws" {
  alias  = "qa"
  region = "us-east-1"
  
  assume_role {
    role_arn = "arn:aws:iam::234567890123:role/QAAccountAccessRole"
  }
  
  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Project     = "iam-management"
      Environment = "qa"
      Account     = "qa-staging"
      AccountId   = "234567890123"
    }
  }
}

# Production Account Provider
provider "aws" {
  alias  = "prod"
  region = "us-east-1"
  
  assume_role {
    role_arn = "arn:aws:iam::123456789012:role/ProductionAccountAccessRole"
  }
  
  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Project     = "iam-management"
      Environment = "prod"
      Account     = "production"
      AccountId   = "123456789012"
      Critical    = "true"
    }
  }
}