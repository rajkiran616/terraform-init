# Variables for Development Environment

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "assume_role_arn" {
  description = "ARN of the role to assume in the development account"
  type        = string
  # Example: "arn:aws:iam::123456789012:role/TerraformCrossAccountRole"
}

variable "external_id" {
  description = "External ID for assume role"
  type        = string
  default     = ""
}

variable "audit_assume_role_arn" {
  description = "ARN of the role to assume in the audit account"
  type        = string
  default     = ""
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "multi-account-infrastructure"
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "infrastructure-team"
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "engineering"
}