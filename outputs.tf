# Output from active environment module
output "created_policies" {
  description = "Map of created IAM policies for the selected environment"
  value = var.environment == "dev" ? (
    length(module.iam_dev) > 0 ? module.iam_dev[0].created_policies : {}
  ) : var.environment == "qa" ? (
    length(module.iam_qa) > 0 ? module.iam_qa[0].created_policies : {}
  ) : (
    length(module.iam_prod) > 0 ? module.iam_prod[0].created_policies : {}
  )
}

output "created_roles" {
  description = "Map of created IAM roles for the selected environment"
  value = var.environment == "dev" ? (
    length(module.iam_dev) > 0 ? module.iam_dev[0].created_roles : {}
  ) : var.environment == "qa" ? (
    length(module.iam_qa) > 0 ? module.iam_qa[0].created_roles : {}
  ) : (
    length(module.iam_prod) > 0 ? module.iam_prod[0].created_roles : {}
  )
}

output "policy_arns" {
  description = "Map of policy keys to ARNs for the selected environment"
  value = var.environment == "dev" ? (
    length(module.iam_dev) > 0 ? module.iam_dev[0].policy_arns : {}
  ) : var.environment == "qa" ? (
    length(module.iam_qa) > 0 ? module.iam_qa[0].policy_arns : {}
  ) : (
    length(module.iam_prod) > 0 ? module.iam_prod[0].policy_arns : {}
  )
}

output "role_arns" {
  description = "Map of role keys to ARNs for the selected environment"
  value = var.environment == "dev" ? (
    length(module.iam_dev) > 0 ? module.iam_dev[0].role_arns : {}
  ) : var.environment == "qa" ? (
    length(module.iam_qa) > 0 ? module.iam_qa[0].role_arns : {}
  ) : (
    length(module.iam_prod) > 0 ? module.iam_prod[0].role_arns : {}
  )
}

output "environment_info" {
  description = "Information about the selected environment"
  value = {
    environment        = local.environment_config.environment
    account_id         = local.environment_config.account_id
    account_name       = local.environment_config.account_name
    region             = local.environment_config.region
    cross_account_role = local.environment_config.cross_account_role
  }
}
