# Backend configuration variables
# Update these values in terraform.tfvars or set as environment variables

variable "state_bucket_name" {
  description = "S3 bucket name for storing Terraform state (must have versioning enabled)"
  type        = string
  default     = "your-terraform-state-bucket"
}

variable "state_region" {
  description = "AWS region for state storage"
  type        = string
  default     = "us-east-1"
}

# Note: DynamoDB table no longer required for state locking
# S3 now provides native state locking when versioning is enabled
