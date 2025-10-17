variable "environment" {
  description = "Environment name"
  type        = string
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "account_name" {
  description = "AWS Account name"
  type        = string
}

variable "iam_policies" {
  description = "Map of IAM policies to create"
  type = map(object({
    name        = string
    description = string
    document    = string
    tags        = map(string)
  }))
  default = {}
}

variable "iam_roles" {
  description = "Map of IAM roles to create"
  type = map(object({
    name               = string
    description        = string
    assume_role_policy = string
    tags               = map(string)
  }))
  default = {}
}