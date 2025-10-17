# Development Environment Configuration
locals {
  dev_config = {
    environment = "dev"
    account_id  = "345678901234"
    account_name = "development"
    region = "us-west-2"
    cross_account_role = "DevelopmentAccountAccessRole"
    
    iam_policies = {
      developer_policy = {
        name        = "DeveloperAccess-Dev"
        description = "Full developer access policy for development environment"
        document = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect   = "Allow"
              Action   = "*"
              Resource = "*"
            }
          ]
        })
        tags = {
          Environment = "dev"
          Team        = "engineering"
          Access      = "full"
        }
      }
      
      s3_dev_policy = {
        name        = "S3DevAccess-Dev"
        description = "S3 access for development buckets"
        document = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect = "Allow"
              Action = ["s3:*"]
              Resource = [
                "arn:aws:s3:::dev-*",
                "arn:aws:s3:::dev-*/*"
              ]
            }
          ]
        })
        tags = {
          Environment = "dev"
          Service     = "s3"
        }
      }
      
      lambda_dev_policy = {
        name        = "LambdaDevAccess-Dev"
        description = "Lambda development access"
        document = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect = "Allow"
              Action = [
                "lambda:*",
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
              ]
              Resource = "*"
            }
          ]
        })
        tags = {
          Environment = "dev"
          Service     = "lambda"
        }
      }
    }
    
    iam_roles = {
      app_execution_role = {
        name        = "AppExecutionRole-Dev"
        description = "Execution role for development applications"
        assume_role_policy = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect = "Allow"
              Principal = {
                Service = [
                  "ec2.amazonaws.com",
                  "lambda.amazonaws.com",
                  "ecs-tasks.amazonaws.com"
                ]
              }
              Action = "sts:AssumeRole"
            }
          ]
        })
        tags = {
          Environment = "dev"
          Type        = "application"
        }
      }
      
      data_access_role = {
        name        = "DataAccessRole-Dev"
        description = "Data access role for development data sources"
        assume_role_policy = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect = "Allow"
              Principal = {
                Service = [
                  "glue.amazonaws.com",
                  "databrew.amazonaws.com"
                ]
              }
              Action = "sts:AssumeRole"
            }
          ]
        })
        tags = {
          Environment = "dev"
          Type        = "data"
        }
      }
    }
  }
}