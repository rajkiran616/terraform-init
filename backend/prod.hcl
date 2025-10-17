bucket  = "your-terraform-state-bucket"
key     = "iam-management/prod/terraform.tfstate"
region  = "us-east-1"
encrypt = true

# S3 native state locking enabled automatically when versioning is on
# No DynamoDB configuration needed