# IAM Management Module Outputs - For Each Pattern
# Returns maps of all created resources for easy reference

output "iam_policies" {
  description = "Map of IAM policy resources"
  value = {
    for k, v in aws_iam_policy.this : k => {
      id          = v.id
      arn         = v.arn
      name        = v.name
      path        = v.path
      description = v.description
      policy      = v.policy
      tags        = v.tags_all
    }
  }
}

output "iam_roles" {
  description = "Map of IAM role resources"
  value = {
    for k, v in aws_iam_role.this : k => {
      id                   = v.id
      arn                  = v.arn
      name                 = v.name
      path                 = v.path
      description          = v.description
      assume_role_policy   = v.assume_role_policy
      max_session_duration = v.max_session_duration
      permissions_boundary = v.permissions_boundary
      unique_id           = v.unique_id
      tags                = v.tags_all
    }
  }
}

output "iam_users" {
  description = "Map of IAM user resources"
  value = {
    for k, v in aws_iam_user.this : k => {
      id                   = v.id
      arn                  = v.arn
      name                 = v.name
      path                 = v.path
      permissions_boundary = v.permissions_boundary
      unique_id           = v.unique_id
      tags                = v.tags_all
    }
  }
}

output "iam_groups" {
  description = "Map of IAM group resources"
  value = {
    for k, v in aws_iam_group.this : k => {
      id        = v.id
      arn       = v.arn
      name      = v.name
      path      = v.path
      unique_id = v.unique_id
    }
  }
}

output "iam_instance_profiles" {
  description = "Map of IAM instance profile resources"
  value = {
    for k, v in aws_iam_instance_profile.this : k => {
      id        = v.id
      arn       = v.arn
      name      = v.name
      path      = v.path
      role      = v.role
      unique_id = v.unique_id
      tags      = v.tags_all
    }
  }
}

output "iam_role_policy_attachments" {
  description = "Map of IAM role policy attachment resources"
  value = {
    for k, v in aws_iam_role_policy_attachment.this : k => {
      id         = v.id
      role       = v.role
      policy_arn = v.policy_arn
    }
  }
}

output "iam_user_policy_attachments" {
  description = "Map of IAM user policy attachment resources"
  value = {
    for k, v in aws_iam_user_policy_attachment.this : k => {
      id         = v.id
      user       = v.user
      policy_arn = v.policy_arn
    }
  }
}

output "iam_group_policy_attachments" {
  description = "Map of IAM group policy attachment resources"
  value = {
    for k, v in aws_iam_group_policy_attachment.this : k => {
      id         = v.id
      group      = v.group
      policy_arn = v.policy_arn
    }
  }
}

output "iam_group_memberships" {
  description = "Map of IAM group membership resources"
  value = {
    for k, v in aws_iam_group_membership.this : k => {
      id    = v.id
      name  = v.name
      group = v.group
      users = v.users
    }
  }
}

output "iam_access_keys" {
  description = "Map of IAM access key resources"
  value = {
    for k, v in aws_iam_access_key.this : k => {
      id                    = v.id
      user                  = v.user
      access_key_id        = v.id
      encrypted_secret     = v.encrypted_secret
      encrypted_ses_smtp_password_v4 = v.encrypted_ses_smtp_password_v4
      key_fingerprint      = v.key_fingerprint
      secret               = v.secret
      ses_smtp_password_v4 = v.ses_smtp_password_v4
      status               = v.status
    }
  }
  sensitive = true
}

output "iam_user_login_profiles" {
  description = "Map of IAM user login profile resources"
  value = {
    for k, v in aws_iam_user_login_profile.this : k => {
      user                    = v.user
      encrypted_password      = v.encrypted_password
      key_fingerprint        = v.key_fingerprint
      password               = v.password
      password_reset_required = v.password_reset_required
    }
  }
  sensitive = true
}

output "iam_saml_providers" {
  description = "Map of IAM SAML provider resources"
  value = {
    for k, v in aws_iam_saml_provider.this : k => {
      id                     = v.id
      arn                    = v.arn
      name                   = v.name
      saml_metadata_document = v.saml_metadata_document
      valid_until           = v.valid_until
      tags                  = v.tags_all
    }
  }
}

output "iam_oidc_providers" {
  description = "Map of IAM OIDC provider resources"
  value = {
    for k, v in aws_iam_openid_connect_provider.this : k => {
      id              = v.id
      arn             = v.arn
      url             = v.url
      client_id_list  = v.client_id_list
      thumbprint_list = v.thumbprint_list
      tags           = v.tags_all
    }
  }
}

# Convenience outputs for common use cases
output "policy_arns" {
  description = "Map of policy names to ARNs"
  value       = { for k, v in aws_iam_policy.this : k => v.arn }
}

output "policy_names" {
  description = "Map of policy keys to actual names"
  value       = { for k, v in aws_iam_policy.this : k => v.name }
}

output "role_arns" {
  description = "Map of role names to ARNs"
  value       = { for k, v in aws_iam_role.this : k => v.arn }
}

output "role_names" {
  description = "Map of role keys to actual names"
  value       = { for k, v in aws_iam_role.this : k => v.name }
}

output "user_arns" {
  description = "Map of user names to ARNs"
  value       = { for k, v in aws_iam_user.this : k => v.arn }
}

output "user_names" {
  description = "Map of user keys to actual names"
  value       = { for k, v in aws_iam_user.this : k => v.name }
}

output "group_arns" {
  description = "Map of group names to ARNs"
  value       = { for k, v in aws_iam_group.this : k => v.arn }
}

output "group_names" {
  description = "Map of group keys to actual names"
  value       = { for k, v in aws_iam_group.this : k => v.name }
}

output "instance_profile_arns" {
  description = "Map of instance profile names to ARNs"
  value       = { for k, v in aws_iam_instance_profile.this : k => v.arn }
}

output "instance_profile_names" {
  description = "Map of instance profile keys to actual names"
  value       = { for k, v in aws_iam_instance_profile.this : k => v.name }
}

output "account_info" {
  description = "Account information"
  value = {
    account_id = data.aws_caller_identity.current.account_id
    partition  = data.aws_partition.current.partition
    region     = data.aws_region.current.name
  }
}

output "resource_summary" {
  description = "Summary of created resources"
  value = {
    policies_created             = length(aws_iam_policy.this)
    roles_created               = length(aws_iam_role.this)
    users_created               = length(aws_iam_user.this)
    groups_created              = length(aws_iam_group.this)
    instance_profiles_created   = length(aws_iam_instance_profile.this)
    role_policy_attachments     = length(aws_iam_role_policy_attachment.this)
    user_policy_attachments     = length(aws_iam_user_policy_attachment.this)
    group_policy_attachments    = length(aws_iam_group_policy_attachment.this)
    group_memberships          = length(aws_iam_group_membership.this)
    access_keys                = length(aws_iam_access_key.this)
    user_login_profiles        = length(aws_iam_user_login_profile.this)
    saml_providers             = length(aws_iam_saml_provider.this)
    oidc_providers             = length(aws_iam_openid_connect_provider.this)
    account_id                 = data.aws_caller_identity.current.account_id
  }
}
