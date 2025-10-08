# Root module variables

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "environment" {
  description = "Environment name (development, qa, test, production)"
  type        = string
  validation {
    condition = contains(["development", "qa", "test", "production"], var.environment)
    error_message = "Environment must be one of: development, qa, test, production."
  }
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "iam-management"
}

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Project   = "IAM-Management"
    Owner     = "Platform-Team"
  }
}

# IAM-specific variables
variable "iam_policies" {
  description = "IAM policies to create"
  type = map(object({
    description     = string
    policy_document = string
  }))
  default = {}
}

variable "iam_roles" {
  description = "IAM roles to create"
  type = map(object({
    description              = string
    assume_role_policy      = string
    attached_policies       = list(string)
    max_session_duration    = optional(number, 3600)
    create_instance_profile = optional(bool, false)
  }))
  default = {}
}

variable "policy_prefix" {
  description = "Prefix for IAM policy names"
  type        = string
  default     = ""
}

variable "role_prefix" {
  description = "Prefix for IAM role names"
  type        = string
  default     = ""
}