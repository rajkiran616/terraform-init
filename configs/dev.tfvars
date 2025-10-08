# Development Environment Variables

environment = "development"
region      = "us-east-1"

# IAM Policies for Development
iam_policies = {
  "lambda-basic-execution" = {
    description     = "Basic Lambda execution permissions for dev"
    policy_document = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Resource = "arn:aws:logs:*:*:*"
        }
      ]
    })
  }
  
  "s3-dev-access" = {
    description     = "S3 access for development resources"
    policy_document = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject"
          ]
          Resource = "arn:aws:s3:::dev-*/*"
        },
        {
          Effect = "Allow"
          Action = [
            "s3:ListBucket"
          ]
          Resource = "arn:aws:s3:::dev-*"
        }
      ]
    })
  }
  
  "cloudwatch-dev-access" = {
    description     = "CloudWatch access for development"
    policy_document = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "cloudwatch:PutMetricData",
            "cloudwatch:GetMetricStatistics",
            "cloudwatch:ListMetrics"
          ]
          Resource = "*"
        }
      ]
    })
  }
}

# IAM Roles for Development
iam_roles = {
  "lambda-execution-role" = {
    description              = "Lambda execution role for development"
    max_session_duration    = 3600
    create_instance_profile = false
    assume_role_policy      = jsonencode({
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
    attached_policies = [
      "lambda-basic-execution",
      "s3-dev-access",
      "AWSLambdaBasicExecutionRole"  # AWS managed policy
    ]
  }
  
  "ec2-dev-role" = {
    description              = "EC2 role for development instances"
    max_session_duration    = 7200
    create_instance_profile = true
    assume_role_policy      = jsonencode({
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
    })
    attached_policies = [
      "s3-dev-access",
      "cloudwatch-dev-access",
      "CloudWatchAgentServerPolicy"  # AWS managed policy
    ]
  }
  
  "codebuild-dev-role" = {
    description              = "CodeBuild role for development"
    max_session_duration    = 3600
    create_instance_profile = false
    assume_role_policy      = jsonencode({
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
    })
    attached_policies = [
      "lambda-basic-execution",
      "s3-dev-access"
    ]
  }
}

# Environment-specific settings
default_tags = {
  ManagedBy   = "Terraform"
  Project     = "IAM-Management"
  Owner       = "Platform-Team"
  Environment = "development"
  CostCenter  = "engineering"
}