output "created_policies" {
  description = "All created policies"
  value = {
    for key, policy in aws_iam_policy.policies : key => {
      name = policy.name
      arn  = policy.arn
    }
  }
}

output "organization_accounts" {
  description = "All accounts in the organization"
  value = {
    for account in data.aws_organizations_accounts.this.accounts : account.id => account.name
  }
}