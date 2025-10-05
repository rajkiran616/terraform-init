variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cross_account_role_name" {
  description = "Name of the cross-account role to create in each account"
  type        = string
  default     = "TerraformCrossAccountRole"
}

variable "cross_account_external_id" {
  description = "External ID for cross-account role assumption"
  type        = string
  default     = null
}

variable "cross_account_policy_arns" {
  description = "List of policy ARNs to attach to cross-account roles"
  type        = list(string)
  default     = [
    "arn:aws:iam::aws:policy/PowerUserAccess"
  ]
}

variable "create_cross_account_roles" {
  description = "Whether to create cross-account roles in discovered accounts"
  type        = bool
  default     = false
}

variable "terraform_state_bucket" {
  description = "S3 bucket for Terraform state files"
  type        = string
}

variable "terraform_lock_table" {
  description = "DynamoDB table for Terraform state locking"
  type        = string
}

variable "default_tags" {
  description = "Default tags to apply to resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
  }
}

variable "account_name_pattern" {
  description = "Regex pattern to match account names for filtering"
  type        = string
  default     = ".*"
}

variable "excluded_account_ids" {
  description = "List of account IDs to exclude from processing"
  type        = list(string)
  default     = []
}