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

# Default provider for master account
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      ManagedBy = "terraform"
      Project   = "organization-iam"
    }
  }
}

# Get organization info
data "aws_organizations_organization" "this" {}

# Get all accounts in organization
data "aws_organizations_accounts" "this" {}

# Create provider for the target environment account
provider "aws" {
  alias  = "target_account"
  region = local.region
  
  assume_role {
    role_arn = "arn:aws:iam::${local.account_id}:role/${local.cross_account_role}"
  }
  
  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Project     = "iam-management"
      Account     = local.account_name
      Environment = var.environment
    }
  }
}

# Create IAM policies for the selected environment
resource "aws_iam_policy" "policies" {
  for_each = local.policies_for_deployment

  provider = aws.target_account
  
  name        = each.value.policy_config.name
  description = each.value.policy_config.description
  policy      = each.value.policy_config.document

  tags = merge(
    {
      ManagedBy   = "terraform"
      Account     = each.value.account_name
      AccountId   = each.value.account_id
      Environment = each.value.environment
      PolicyKey   = each.value.policy_key
    },
    each.value.policy_config.tags
  )
}

# Create IAM roles for the selected environment
resource "aws_iam_role" "roles" {
  for_each = local.roles_for_deployment

  provider = aws.target_account
  
  name               = each.value.role_config.name
  description        = each.value.role_config.description
  assume_role_policy = each.value.role_config.assume_role_policy

  tags = merge(
    {
      ManagedBy   = "terraform"
      Account     = each.value.account_name
      AccountId   = each.value.account_id
      Environment = each.value.environment
      RoleKey     = each.value.role_key
    },
    each.value.role_config.tags
  )
}
