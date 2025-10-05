# Development Environment Configuration - Distributed Backend Version
# This version stores state in the target account rather than centrally

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # Backend will be configured via backend-distributed.hcl
  backend "s3" {}
}

# Provider configuration for the target account
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
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = var.project_name
      Owner       = var.owner
      CostCenter  = var.cost_center
    }
  }
}

# Use the IAM policies module
module "iam_policies" {
  source = "../../modules/iam-policies"

  environment  = var.environment
  project_name = var.project_name
  
  # Define policies for development environment
  policies = {
    "dev-s3-access" = {
      description = "S3 access policy for development environment"
      policy_document = {
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "s3:GetObject",
              "s3:PutObject",
              "s3:DeleteObject"
            ]
            Resource = [
              "arn:aws:s3:::${var.project_name}-dev-*/*"
            ]
          },
          {
            Effect = "Allow"
            Action = [
              "s3:ListBucket"
            ]
            Resource = [
              "arn:aws:s3:::${var.project_name}-dev-*"
            ]
          }
        ]
      }
    }
    
    "dev-logs-access" = {
      description = "CloudWatch logs access for development"
      policy_document = {
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "logs:CreateLogGroup",
              "logs:CreateLogStream",
              "logs:PutLogEvents",
              "logs:DescribeLogGroups",
              "logs:DescribeLogStreams"
            ]
            Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/${var.project_name}-dev-*"
          }
        ]
      }
    }

    "dev-secrets-access" = {
      description = "Secrets Manager access for development"
      policy_document = {
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "secretsmanager:GetSecretValue",
              "secretsmanager:DescribeSecret"
            ]
            Resource = "arn:aws:secretsmanager:*:*:secret:${var.project_name}/dev/*"
          }
        ]
      }
    }
  }

  # Define roles for development environment
  roles = {
    "dev-lambda-execution-role" = {
      description = "Lambda execution role for development"
      assume_role_policy = {
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
      }
      attached_policies = [
        "dev-s3-access",
        "dev-logs-access",
        "dev-secrets-access",
        "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
      ]
      max_session_duration = 3600
    }

    "dev-ec2-role" = {
      description = "EC2 role for development instances"
      assume_role_policy = {
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Principal = {
              Service = "ec2.amazonaws.com"
            }
            Action = "sts:AssumeRole"
          }
        ]
      }
      attached_policies = [
        "dev-s3-access",
        "dev-logs-access",
        "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
      ]
      create_instance_profile = true
    }

    "dev-codebuild-role" = {
      description = "CodeBuild role for development CI/CD"
      assume_role_policy = {
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Principal = {
              Service = "codebuild.amazonaws.com"
            }
            Action = "sts:AssumeRole"
          }
        ]
      }
      attached_policies = [
        "dev-s3-access",
        "dev-logs-access",
        "arn:aws:iam::aws:policy/service-role/AWSCodeBuildDeveloperAccess"
      ]
    }
  }

  common_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
    Owner       = var.owner
    CostCenter  = var.cost_center
    StateModel  = "distributed"
  }
}

# Outputs
output "policy_arns" {
  description = "Map of created policy ARNs"
  value       = module.iam_policies.policy_arns
}

output "role_arns" {
  description = "Map of created role ARNs"
  value       = module.iam_policies.role_arns
}

output "instance_profile_arns" {
  description = "Map of created instance profile ARNs"
  value       = module.iam_policies.instance_profile_arns
}