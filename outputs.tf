# Root module outputs

output "account_info" {
  description = "Current account information"
  value       = module.iam_management.account_info
}

output "policy_arns" {
  description = "Created IAM policy ARNs"
  value       = module.iam_management.policy_arns
}

output "role_arns" {
  description = "Created IAM role ARNs"  
  value       = module.iam_management.role_arns
}

output "instance_profile_arns" {
  description = "Created IAM instance profile ARNs"
  value       = module.iam_management.instance_profile_arns
}

output "resource_summary" {
  description = "Summary of all created resources"
  value       = module.iam_management.resource_summary
}

output "deployment_info" {
  description = "Deployment information"
  value = {
    workspace     = terraform.workspace
    account_id    = local.account_id
    region        = local.region
    environment   = var.environment
    deployed_at   = timestamp()
  }
}