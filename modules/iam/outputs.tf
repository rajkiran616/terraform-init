output "cross_account_role_arn" {
  description = "ARN of the cross-account role"
  value       = var.create_cross_account_role ? aws_iam_role.terraform_cross_account_role[0].arn : null
}

output "cross_account_role_name" {
  description = "Name of the cross-account role"
  value       = var.create_cross_account_role ? aws_iam_role.terraform_cross_account_role[0].name : null
}

output "custom_policy_arn" {
  description = "ARN of the custom policy"
  value       = var.create_custom_policy && var.custom_policy_document != null ? aws_iam_policy.terraform_custom_policy[0].arn : null
}

output "infrastructure_group_name" {
  description = "Name of the infrastructure group"
  value       = var.create_infrastructure_group ? aws_iam_group.infrastructure_group[0].name : null
}

output "infrastructure_group_arn" {
  description = "ARN of the infrastructure group"
  value       = var.create_infrastructure_group ? aws_iam_group.infrastructure_group[0].arn : null
}

output "infrastructure_users" {
  description = "Map of created infrastructure users"
  value = {
    for k, v in aws_iam_user.infrastructure_users : k => {
      arn  = v.arn
      name = v.name
    }
  }
}

output "standard_roles" {
  description = "Map of created standard IAM roles"
  value = {
    for k, v in aws_iam_role.standard_roles : k => {
      arn  = v.arn
      name = v.name
    }
  }
}

output "instance_profiles" {
  description = "Map of created instance profiles"
  value = {
    for k, v in aws_iam_instance_profile.standard_instance_profiles : k => {
      arn  = v.arn
      name = v.name
    }
  }
}
