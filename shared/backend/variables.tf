variable "company_name" {
  description = "Company name used for resource naming"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.company_name))
    error_message = "Company name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "aws_region" {
  description = "AWS region for backend resources"
  type        = string
  default     = "us-east-1"
}