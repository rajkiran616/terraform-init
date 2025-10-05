# Simple Test Configuration for Multi-Account Setup
# Use this file for initial testing instead of main.tf

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # Comment out the backend block for initial testing
  # Uncomment after backend is set up
  # backend "s3" {}
}

# Provider configuration for cross-account access
provider "aws" {
  region = var.aws_region
  
  # Comment out assume_role block for local testing with default credentials
  # Uncomment when cross-account roles are set up
  # assume_role {
  #   role_arn     = var.assume_role_arn
  #   session_name = "terraform-${var.environment}"
  #   external_id  = var.external_id
  # }

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = var.project_name
      Owner       = var.owner
      TestRun     = "true"
    }
  }
}

# Simple IAM policy for testing
resource "aws_iam_policy" "test_policy" {
  name        = "${var.project_name}-${var.environment}-test-policy"
  description = "Test policy for multi-account Terraform setup"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-${var.environment}-test-*"
        ]
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-test-policy"
    Environment = var.environment
    Purpose     = "testing"
  }
}

# Simple IAM role for testing
resource "aws_iam_role" "test_role" {
  name = "${var.project_name}-${var.environment}-test-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-test-role"
    Environment = var.environment
    Purpose     = "testing"
  }
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "test_attachment" {
  role       = aws_iam_role.test_role.name
  policy_arn = aws_iam_policy.test_policy.arn
}

# Outputs
output "test_policy_arn" {
  description = "ARN of the test policy"
  value       = aws_iam_policy.test_policy.arn
}

output "test_role_arn" {
  description = "ARN of the test role"
  value       = aws_iam_role.test_role.arn
}