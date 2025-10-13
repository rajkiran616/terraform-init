# IAM Management Module Variables - For Each Pattern
# Configuration objects for creating IAM resources dynamically

variable "iam_policies" {
  description = "Map of IAM policy configurations"
  type = map(object({
    name            = optional(string)
    name_prefix     = optional(string)
    description     = optional(string, "Policy managed by Terraform")
    path            = optional(string, "/")
    policy_document = string
    tags            = optional(map(string), {})
  }))
  default = {}
}

variable "iam_roles" {
  description = "Map of IAM role configurations"
  type = map(object({
    name                  = optional(string)
    name_prefix          = optional(string)
    description          = optional(string, "Role managed by Terraform")
    path                 = optional(string, "/")
    assume_role_policy   = string
    max_session_duration = optional(number, 3600)
    permissions_boundary = optional(string)
    force_detach_policies = optional(bool, false)
    inline_policies = optional(list(object({
      name   = string
      policy = string
    })), [])
    tags = optional(map(string), {})
  }))
  default = {}
}

variable "iam_users" {
  description = "Map of IAM user configurations"
  type = map(object({
    name                 = optional(string)
    path                 = optional(string, "/")
    permissions_boundary = optional(string)
    force_destroy       = optional(bool, false)
    tags                = optional(map(string), {})
  }))
  default = {}
}

variable "iam_groups" {
  description = "Map of IAM group configurations"
  type = map(object({
    name = optional(string)
    path = optional(string, "/")
  }))
  default = {}
}

variable "iam_instance_profiles" {
  description = "Map of IAM instance profile configurations"
  type = map(object({
    name        = optional(string)
    name_prefix = optional(string)
    path        = optional(string, "/")
    role_key    = optional(string) # Reference to role created in this module
    role_name   = optional(string) # Reference to existing role
    tags        = optional(map(string), {})
  }))
  default = {}
}

variable "iam_role_policy_attachments" {
  description = "Map of IAM role policy attachment configurations"
  type = map(object({
    role_key   = optional(string) # Reference to role created in this module
    role_name  = optional(string) # Reference to existing role
    policy_key = optional(string) # Reference to policy created in this module
    policy_arn = optional(string) # ARN of existing policy
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.iam_role_policy_attachments : (
        (v.role_key != null || v.role_name != null) &&
        (v.policy_key != null || v.policy_arn != null)
      )
    ])
    error_message = "Each attachment must specify either role_key or role_name, and either policy_key or policy_arn."
  }
}

variable "iam_user_policy_attachments" {
  description = "Map of IAM user policy attachment configurations"
  type = map(object({
    user_key   = optional(string) # Reference to user created in this module
    user_name  = optional(string) # Reference to existing user
    policy_key = optional(string) # Reference to policy created in this module
    policy_arn = optional(string) # ARN of existing policy
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.iam_user_policy_attachments : (
        (v.user_key != null || v.user_name != null) &&
        (v.policy_key != null || v.policy_arn != null)
      )
    ])
    error_message = "Each attachment must specify either user_key or user_name, and either policy_key or policy_arn."
  }
}

variable "iam_group_policy_attachments" {
  description = "Map of IAM group policy attachment configurations"
  type = map(object({
    group_key  = optional(string) # Reference to group created in this module
    group_name = optional(string) # Reference to existing group
    policy_key = optional(string) # Reference to policy created in this module
    policy_arn = optional(string) # ARN of existing policy
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.iam_group_policy_attachments : (
        (v.group_key != null || v.group_name != null) &&
        (v.policy_key != null || v.policy_arn != null)
      )
    ])
    error_message = "Each attachment must specify either group_key or group_name, and either policy_key or policy_arn."
  }
}

variable "iam_group_memberships" {
  description = "Map of IAM group membership configurations"
  type = map(object({
    group_key  = optional(string) # Reference to group created in this module
    group_name = optional(string) # Reference to existing group
    users      = list(string)     # List of user keys/names
  }))
  default = {}
}

variable "iam_access_keys" {
  description = "Map of IAM access key configurations"
  type = map(object({
    user_key  = optional(string) # Reference to user created in this module
    user_name = optional(string) # Reference to existing user
    status    = optional(string, "Active")
    pgp_key   = optional(string)
  }))
  default = {}
}

variable "iam_user_login_profiles" {
  description = "Map of IAM user login profile configurations"
  type = map(object({
    user_key                = optional(string) # Reference to user created in this module
    user_name               = optional(string) # Reference to existing user
    pgp_key                = string
    password_length        = optional(number, 20)
    password_reset_required = optional(bool, true)
  }))
  default = {}
}

variable "iam_saml_providers" {
  description = "Map of IAM SAML provider configurations"
  type = map(object({
    saml_metadata_document = string
    tags                   = optional(map(string), {})
  }))
  default = {}
}

variable "iam_oidc_providers" {
  description = "Map of IAM OIDC provider configurations"
  type = map(object({
    url             = string
    client_id_list  = list(string)
    thumbprint_list = list(string)
    tags           = optional(map(string), {})
  }))
  default = {}
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
