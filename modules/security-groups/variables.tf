# Security Groups Module Variables - For Each Pattern
# Configuration objects for creating security group resources dynamically

variable "security_groups" {
  description = "Map of security group configurations"
  type = map(object({
    name                   = optional(string)
    name_prefix           = optional(string)
    description           = optional(string, "Security group managed by Terraform")
    vpc_id                = string
    revoke_rules_on_delete = optional(bool, false)
    tags                  = optional(map(string), {})
  }))
  default = {}
}

variable "security_group_rules" {
  description = "Map of security group rule configurations"
  type = map(object({
    security_group_key        = string
    type                      = string # ingress or egress
    from_port                = number
    to_port                  = number
    protocol                 = string
    description              = optional(string)
    cidr_blocks              = optional(list(string))
    ipv6_cidr_blocks         = optional(list(string))
    prefix_list_ids          = optional(list(string))
    source_security_group_id = optional(string) # Use for existing SG IDs
    source_security_group_key = optional(string) # Use for SGs created in this module
    self                     = optional(bool)
  }))
  default = {}
}

variable "managed_prefix_lists" {
  description = "Map of managed prefix list configurations"
  type = map(object({
    address_family = optional(string, "IPv4")
    max_entries    = number
    entries = optional(list(object({
      cidr        = string
      description = optional(string)
    })), [])
    tags = optional(map(string), {})
  }))
  default = {}
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
