variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cross_account_role_name" {
  description = "Role name to assume in member accounts"
  type        = string
  default     = "OrganizationAccountAccessRole"
}

variable "iam_policies" {
  description = "IAM policies to create in all accounts (deprecated - use JSON config instead)"
  type = map(object({
    name        = string
    description = string
    document    = string
    tags        = optional(map(string), {})
  }))
  default = {}
}

variable "environment" {
  description = "Environment to deploy (dev, qa, prod)"
  type        = string
  
  validation {
    condition = contains(["dev", "qa", "prod"], var.environment)
    error_message = "The environment must be one of: dev, qa, prod."
  }
}
