variable "aws_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "root_account_role_arn" {
  description = "ARN of the role to assume in the root account"
  type        = string
  default     = null
}

variable "dev_account_role_arn" {
  description = "ARN of the role to assume in the development account"
  type        = string
}

variable "staging_account_role_arn" {
  description = "ARN of the role to assume in the staging account"
  type        = string
}

variable "prod_account_role_arn" {
  description = "ARN of the role to assume in the production account"
  type        = string
}

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Owner     = "Infrastructure"
  }
}