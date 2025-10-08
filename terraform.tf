# Terraform configuration and providers
terraform {
  required_version = ">= 1.6"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # Backend configuration will be provided via backend config files
  backend "s3" {}
}

# AWS Provider configuration
# Credentials will be provided via assumed role from scripts
provider "aws" {
  region = var.region
  
  # Default tags applied to all resources
  default_tags {
    tags = var.default_tags
  }
}