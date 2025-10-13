# Security Groups Module
# Creates security groups and rules based on configuration objects using for_each pattern
# This design allows for flexible resource creation and easy importing of existing resources

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Security Groups
resource "aws_security_group" "this" {
  for_each = var.security_groups

  name        = lookup(each.value, "name", null)
  name_prefix = lookup(each.value, "name_prefix", null)
  description = lookup(each.value, "description", "Security group managed by Terraform")
  vpc_id      = each.value.vpc_id

  # Handle revoke_rules_on_delete
  revoke_rules_on_delete = lookup(each.value, "revoke_rules_on_delete", false)

  tags = merge(
    var.common_tags,
    lookup(each.value, "tags", {}),
    {
      Name = each.key
      Type = "SecurityGroup"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group Rules
resource "aws_security_group_rule" "this" {
  for_each = var.security_group_rules

  type              = each.value.type
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  description       = lookup(each.value, "description", null)
  security_group_id = aws_security_group.this[each.value.security_group_key].id

  # Source/Destination specifications
  cidr_blocks              = lookup(each.value, "cidr_blocks", null)
  ipv6_cidr_blocks        = lookup(each.value, "ipv6_cidr_blocks", null)
  prefix_list_ids         = lookup(each.value, "prefix_list_ids", null)
  source_security_group_id = lookup(each.value, "source_security_group_key", null) != null ? aws_security_group.this[each.value.source_security_group_key].id : lookup(each.value, "source_security_group_id", null)
  self                    = lookup(each.value, "self", null)

  # For egress rules, handle destination security group
  # Note: AWS uses source_security_group_id for both ingress source and egress destination
}

# Managed Prefix Lists (optional)
resource "aws_ec2_managed_prefix_list" "this" {
  for_each = var.managed_prefix_lists

  name           = each.key
  address_family = lookup(each.value, "address_family", "IPv4")
  max_entries    = each.value.max_entries

  dynamic "entry" {
    for_each = lookup(each.value, "entries", [])
    content {
      cidr        = entry.value.cidr
      description = lookup(entry.value, "description", null)
    }
  }

  tags = merge(
    var.common_tags,
    lookup(each.value, "tags", {}),
    {
      Name = each.key
      Type = "ManagedPrefixList"
    }
  )
}
