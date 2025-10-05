# Outputs for IAM Policies Module

output "policy_arns" {
  description = "Map of policy names to ARNs"
  value = {
    for name, policy in aws_iam_policy.custom_policy : name => policy.arn
  }
}

output "policy_ids" {
  description = "Map of policy names to IDs"
  value = {
    for name, policy in aws_iam_policy.custom_policy : name => policy.id
  }
}

output "role_arns" {
  description = "Map of role names to ARNs"
  value = {
    for name, role in aws_iam_role.custom_role : name => role.arn
  }
}

output "role_names" {
  description = "Map of role names"
  value = {
    for name, role in aws_iam_role.custom_role : name => role.name
  }
}

output "instance_profile_arns" {
  description = "Map of instance profile names to ARNs"
  value = {
    for name, profile in aws_iam_instance_profile.instance_profile : name => profile.arn
  }
}

output "instance_profile_names" {
  description = "Map of instance profile names"
  value = {
    for name, profile in aws_iam_instance_profile.instance_profile : name => profile.name
  }
}