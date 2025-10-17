# Production Environment Configuration
locals {
  prod_config = {
    environment = "prod"
    account_id  = "123456789012"
    account_name = "production"
    region = "us-east-1"
    cross_account_role = "ProductionAccountAccessRole"
    
    iam_policies = {
      readonly_policy = {
        name        = "ReadOnlyAccess-Prod"
        description = "Read-only access policy for production environment"
        document = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect = "Allow"
              Action = [
                "s3:GetObject",
                "s3:ListBucket",
                "cloudwatch:GetMetricStatistics",
                "cloudwatch:ListMetrics",
                "logs:FilterLogEvents",
                "logs:GetLogEvents",
                "ec2:DescribeInstances",
                "rds:DescribeDBInstances",
                "lambda:GetFunction",
                "lambda:ListFunctions"
              ]
              Resource = "*"
            }
          ]
        })
        tags = {
          Environment = "prod"
          Team        = "operations"
          Access      = "readonly"
        }
      }
      
      limited_dev_policy = {
        name        = "LimitedDevAccess-Prod"
        description = "Limited developer access for production troubleshooting"
        document = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect = "Allow"
              Action = [
                "logs:FilterLogEvents",
                "logs:GetLogEvents",
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams",
                "cloudwatch:GetMetricStatistics",
                "cloudwatch:ListMetrics"
              ]
              Resource = "*"
            },
            {
              Effect = "Allow"
              Action = [
                "s3:GetObject",
                "s3:ListBucket"
              ]
              Resource = [
                "arn:aws:s3:::prod-logs-*",
                "arn:aws:s3:::prod-logs-*/*"
              ]
            }
          ]
        })
        tags = {
          Environment = "prod"
          Team        = "engineering"
          Access      = "limited"
        }
      }
      
      deployment_policy = {
        name        = "DeploymentAccess-Prod"
        description = "Deployment access for production releases"
        document = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect = "Allow"
              Action = [
                "lambda:UpdateFunctionCode",
                "lambda:PublishVersion",
                "lambda:UpdateAlias",
                "ecs:UpdateService",
                "ecs:DescribeServices",
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability", 
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage"
              ]
              Resource = "*"
            },
            {
              Effect = "Allow"
              Action = [
                "s3:PutObject",
                "s3:GetObject"
              ]
              Resource = [
                "arn:aws:s3:::prod-deployment-*",
                "arn:aws:s3:::prod-deployment-*/*"
              ]
            }
          ]
        })
        tags = {
          Environment = "prod"
          Team        = "devops"
          Access      = "deployment"
        }
      }
    }
    
    iam_roles = {
      app_execution_role = {
        name        = "AppExecutionRole-Prod"
        description = "Execution role for production applications"
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
          Environment = "prod"
          Type        = "application"
          Critical    = "true"
        }
      }
      
      monitoring_role = {
        name        = "MonitoringRole-Prod"
        description = "Role for monitoring and alerting systems in production"
        assume_role_policy = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect = "Allow"
              Principal = {
                Service = [
                  "lambda.amazonaws.com",
                  "events.amazonaws.com"
                ]
              }
              Action = "sts:AssumeRole"
            }
          ]
        })
        tags = {
          Environment = "prod"
          Type        = "monitoring"
          Critical    = "true"
        }
      }
      
      backup_role = {
        name        = "BackupRole-Prod"
        description = "Role for backup and disaster recovery operations"
        assume_role_policy = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect = "Allow"
              Principal = {
                Service = [
                  "backup.amazonaws.com",
                  "lambda.amazonaws.com"
                ]
              }
              Action = "sts:AssumeRole"
            }
          ]
        })
        tags = {
          Environment = "prod"
          Type        = "backup"
          Critical    = "true"
        }
      }
    }
  }
}