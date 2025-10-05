variable "create_cross_account_role" {
  description = "Whether to create cross-account access role"
  type        = bool
  default     = true
}

variable "cross_account_role_name" {
  description = "Name of the cross-account role"
  type        = string
  default     = "TerraformCrossAccountRole"
}

variable "trusted_account_arns" {
  description = "List of trusted AWS account ARNs that can assume the cross-account role"
  type        = list(string)
  default     = []
}

variable "external_id" {
  description = "External ID for additional security when assuming cross-account role"
  type        = string
  default     = null
}

variable "policy_arns" {
  description = "List of IAM policy ARNs to attach to the cross-account role"
  type        = list(string)
  default     = [
    "arn:aws:iam::aws:policy/PowerUserAccess"
  ]
}

variable "create_custom_policy" {
  description = "Whether to create a custom policy"
  type        = bool
  default     = false
}

variable "custom_policy_name" {
  description = "Name of the custom policy"
  type        = string
  default     = "TerraformCustomPolicy"
}

variable "custom_policy_description" {
  description = "Description of the custom policy"
  type        = string
  default     = "Custom policy for Terraform cross-account access"
}

variable "custom_policy_document" {
  description = "Custom policy document in JSON format"
  type        = string
  default     = null
}

variable "create_infrastructure_group" {
  description = "Whether to create infrastructure group"
  type        = bool
  default     = false
}

variable "infrastructure_group_name" {
  description = "Name of the infrastructure group"
  type        = string
  default     = "InfrastructureTeam"
}

variable "group_policy_arns" {
  description = "List of IAM policy ARNs to attach to the infrastructure group"
  type        = list(string)
  default     = []
}

variable "infrastructure_users" {
  description = "Map of infrastructure users to create"
  type = map(object({
    role = string
  }))
  default = {}
}

variable "standard_roles" {
  description = "Map of standard IAM roles to create"
  type = map(object({
    description           = string
    trusted_entities     = list(string)
    managed_policy_arns  = list(string)
    inline_policies      = optional(map(string), {})
    max_session_duration = optional(number, 3600)
    conditions           = optional(map(any), {})
    tags                 = optional(map(string), {})
  }))
  default = {}
}

variable "tags" {
  description = "Tags to apply to all IAM resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Module    = "iam"
  }
}