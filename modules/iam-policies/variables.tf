# Variables for IAM Policies Module

variable "policies" {
  description = "Map of IAM policies to create"
  type = map(object({
    description     = string
    policy_document = any
  }))
  default = {}
}

variable "roles" {
  description = "Map of IAM roles to create"
  type = map(object({
    description              = string
    assume_role_policy      = any
    attached_policies       = list(string)
    max_session_duration    = optional(number, 3600)
    create_instance_profile = optional(bool, false)
  }))
  default = {}
}

variable "policy_path" {
  description = "Path for IAM policies"
  type        = string
  default     = "/"
}

variable "role_path" {
  description = "Path for IAM roles"
  type        = string
  default     = "/"
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = ""
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = ""
}