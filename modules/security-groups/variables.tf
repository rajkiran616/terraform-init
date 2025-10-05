variable "name_prefix" {
  description = "Prefix for security group names"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where security groups will be created"
  type        = string
}

variable "create_web_sg" {
  description = "Whether to create web tier security group"
  type        = bool
  default     = true
}

variable "create_app_sg" {
  description = "Whether to create application tier security group"
  type        = bool
  default     = true
}

variable "create_database_sg" {
  description = "Whether to create database tier security group"
  type        = bool
  default     = true
}

variable "create_bastion_sg" {
  description = "Whether to create bastion security group"
  type        = bool
  default     = false
}

variable "create_alb_sg" {
  description = "Whether to create ALB security group"
  type        = bool
  default     = false
}

variable "create_efs_sg" {
  description = "Whether to create EFS security group"
  type        = bool
  default     = false
}

variable "web_ingress_cidrs" {
  description = "CIDR blocks allowed to access web tier"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "bastion_ingress_cidrs" {
  description = "CIDR blocks allowed to access bastion"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "alb_ingress_cidrs" {
  description = "CIDR blocks allowed to access ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "app_port" {
  description = "Port for application tier"
  type        = number
  default     = 8080
}

variable "bastion_sg_id" {
  description = "Security group ID of bastion host"
  type        = string
  default     = null
}

variable "custom_security_groups" {
  description = "Map of custom security groups to create"
  type = map(object({
    description = string
    ingress_rules = list(object({
      from_port                = number
      to_port                  = number
      protocol                 = string
      cidr_blocks              = optional(list(string))
      source_security_group_id = optional(string)
      description              = optional(string)
    }))
    egress_rules = list(object({
      from_port                     = number
      to_port                       = number
      protocol                      = string
      cidr_blocks                   = optional(list(string))
      destination_security_group_id = optional(string)
      description                   = optional(string)
    }))
    tags = optional(map(string), {})
  }))
  default = {}
}

variable "tags" {
  description = "Tags to apply to all security groups"
  type        = map(string)
  default     = {}
}