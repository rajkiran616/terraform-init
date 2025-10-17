output "policy_arns" {
  description = "Map of policy keys to their ARNs"
  value = {
    for key, policy in aws_iam_policy.policies : key => policy.arn
  }
}

output "policy_names" {
  description = "Map of policy keys to their names"
  value = {
    for key, policy in aws_iam_policy.policies : key => policy.name
  }
}

output "role_arns" {
  description = "Map of role keys to their ARNs"
  value = {
    for key, role in aws_iam_role.roles : key => role.arn
  }
}

output "role_names" {
  description = "Map of role keys to their names"
  value = {
    for key, role in aws_iam_role.roles : key => role.name
  }
}

output "created_policies" {
  description = "Details of created policies"
  value = {
    for key, policy in aws_iam_policy.policies : key => {
      name = policy.name
      arn  = policy.arn
      id   = policy.id
    }
  }
}

output "created_roles" {
  description = "Details of created roles"
  value = {
    for key, role in aws_iam_role.roles : key => {
      name = role.name
      arn  = role.arn
      id   = role.id
    }
  }
}