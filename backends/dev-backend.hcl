# Development Account Backend Configuration
# Update the bucket name with your actual dev account backend bucket

bucket         = "terraform-state-dev-111111111111"
key            = "iam-management/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-locks-dev"
encrypt        = true

# Enable versioning and point-in-time recovery
# These should be configured on the S3 bucket and DynamoDB table