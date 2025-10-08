# Variables for IAM Management Module

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
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

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "policies" {
  description = "Map of IAM policies to create"
  type = map(object({
    description     = string
    policy_document = string
  }))
  default = {}
}

variable "roles" {
  description = "Map of IAM roles to create"
  type = map(object({
    description              = string
    assume_role_policy      = string
    attached_policies       = list(string)
    max_session_duration    = optional(number, 3600)
    create_instance_profile = optional(bool, false)
  }))
  default = {}
}