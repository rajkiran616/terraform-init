# Outputs for IAM Management Module

output "policy_arns" {
  description = "Map of created policy names to ARNs"
  value = {
    for name, policy in aws_iam_policy.custom : name => policy.arn
  }
}

output "policy_names" {
  description = "Map of created policy keys to actual names"
  value = {
    for name, policy in aws_iam_policy.custom : name => policy.name
  }
}

output "role_arns" {
  description = "Map of created role names to ARNs"
  value = {
    for name, role in aws_iam_role.custom : name => role.arn
  }
}

output "role_names" {
  description = "Map of created role keys to actual names"
  value = {
    for name, role in aws_iam_role.custom : name => role.name
  }
}

output "instance_profile_arns" {
  description = "Map of created instance profile names to ARNs"
  value = {
    for name, profile in aws_iam_instance_profile.custom : name => profile.arn
  }
}

output "instance_profile_names" {
  description = "Map of created instance profile keys to actual names"
  value = {
    for name, profile in aws_iam_instance_profile.custom : name => profile.name
  }
}

output "account_info" {
  description = "Account information"
  value = {
    account_id  = data.aws_caller_identity.current.account_id
    environment = var.environment
    region      = var.region
  }
}

output "resource_summary" {
  description = "Summary of created resources"
  value = {
    policies_created          = length(aws_iam_policy.custom)
    roles_created            = length(aws_iam_role.custom)
    instance_profiles_created = length(aws_iam_instance_profile.custom)
    environment              = var.environment
    account_id               = data.aws_caller_identity.current.account_id
  }
}