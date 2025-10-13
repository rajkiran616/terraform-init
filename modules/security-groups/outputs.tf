# Security Groups Module Outputs - For Each Pattern
# Returns maps of all created resources for easy reference

output "security_groups" {
  description = "Map of security group resources"
  value = {
    for k, v in aws_security_group.this : k => {
      id          = v.id
      arn         = v.arn
      name        = v.name
      description = v.description
      vpc_id      = v.vpc_id
      owner_id    = v.owner_id
      ingress     = v.ingress
      egress      = v.egress
      tags        = v.tags_all
    }
  }
}

output "security_group_rules" {
  description = "Map of security group rule resources"
  value = {
    for k, v in aws_security_group_rule.this : k => {
      id                       = v.id
      type                     = v.type
      from_port               = v.from_port
      to_port                 = v.to_port
      protocol                = v.protocol
      description             = v.description
      security_group_id       = v.security_group_id
      cidr_blocks             = v.cidr_blocks
      ipv6_cidr_blocks        = v.ipv6_cidr_blocks
      prefix_list_ids         = v.prefix_list_ids
      source_security_group_id = v.source_security_group_id
      self                    = v.self
    }
  }
}

output "managed_prefix_lists" {
  description = "Map of managed prefix list resources"
  value = {
    for k, v in aws_ec2_managed_prefix_list.this : k => {
      id             = v.id
      arn            = v.arn
      name           = v.name
      address_family = v.address_family
      max_entries    = v.max_entries
      version        = v.version
      entries        = v.entry
      tags           = v.tags_all
    }
  }
}

# Convenience outputs for common use cases
output "security_group_ids" {
  description = "Map of security group names to IDs"
  value       = { for k, v in aws_security_group.this : k => v.id }
}

output "security_group_arns" {
  description = "Map of security group names to ARNs"
  value       = { for k, v in aws_security_group.this : k => v.arn }
}

output "managed_prefix_list_ids" {
  description = "Map of managed prefix list names to IDs"
  value       = { for k, v in aws_ec2_managed_prefix_list.this : k => v.id }
}
