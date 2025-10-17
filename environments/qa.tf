# QA/Staging Environment Configuration
locals {
  qa_config = {
    environment = "qa"
    account_id  = "234567890123"
    account_name = "qa-staging"
    region = "us-east-1"
    cross_account_role = "QAAccountAccessRole"
    
    iam_policies = {
      qa_tester_policy = {
        name        = "QATesterAccess-QA"
        description = "QA tester access policy for staging environment"
        document = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect = "Allow"
              Action = [
                "s3:GetObject",
                "s3:PutObject",
                "s3:ListBucket",
                "s3:DeleteObject"
              ]
              Resource = [
                "arn:aws:s3:::qa-*",
                "arn:aws:s3:::qa-*/*",
                "arn:aws:s3:::staging-*",
                "arn:aws:s3:::staging-*/*"
              ]
            },
            {
              Effect = "Allow"
              Action = [
                "ec2:DescribeInstances",
                "ec2:DescribeImages",
                "rds:DescribeDBInstances",
                "lambda:ListFunctions",
                "lambda:GetFunction"
              ]
              Resource = "*"
            }
          ]
        })
        tags = {
          Environment = "qa"
          Team        = "qa"
          Access      = "limited"
        }
      }
      
      developer_qa_policy = {
        name        = "DeveloperQAAccess-QA"
        description = "Developer access policy for QA environment"
        document = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect = "Allow"
              Action = [
                "s3:*",
                "ec2:DescribeInstances",
                "ec2:StartInstances",
                "ec2:StopInstances",
                "rds:DescribeDBInstances",
                "lambda:*",
                "logs:*",
                "cloudwatch:GetMetricStatistics"
              ]
              Resource = "*"
            }
          ]
        })
        tags = {
          Environment = "qa"
          Team        = "engineering"
          Access      = "moderate"
        }
      }
      
      automation_policy = {
        name        = "AutomationAccess-QA"
        description = "Automation and CI/CD access for QA environment"
        document = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect = "Allow"
              Action = [
                "s3:*",
                "lambda:UpdateFunctionCode",
                "lambda:PublishVersion",
                "ecs:UpdateService",
                "ecs:DescribeServices",
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage"
              ]
              Resource = "*"
            }
          ]
        })
        tags = {
          Environment = "qa"
          Team        = "devops"
          Access      = "automation"
        }
      }
    }
    
    iam_roles = {
      app_execution_role = {
        name        = "AppExecutionRole-QA"
        description = "Execution role for QA applications"
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
          Environment = "qa"
          Type        = "application"
        }
      }
      
      test_execution_role = {
        name        = "TestExecutionRole-QA"
        description = "Role for automated test execution in QA"
        assume_role_policy = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect = "Allow"
              Principal = {
                Service = [
                  "codebuild.amazonaws.com",
                  "lambda.amazonaws.com"
                ]
              }
              Action = "sts:AssumeRole"
            }
          ]
        })
        tags = {
          Environment = "qa"
          Type        = "testing"
        }
      }
    }
  }
}