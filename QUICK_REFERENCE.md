# 🚀 Quick Reference Guide

## Essential Commands

### Initial Setup (One-time)
```bash
# 1. Install Terraform
brew install hashicorp/tap/terraform

# 2. Get your management account ID
MANAGEMENT_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Management Account ID: $MANAGEMENT_ACCOUNT_ID"

# 3. Set up distributed backend for each account
cd shared/backend
./setup-distributed-backend.sh -e dev -r arn:aws:iam::DEV-ACCOUNT-ID:role/TerraformCrossAccountRole -x your-external-id -a development -p my-company
```

### Daily Operations

#### Deploy to Environment
```bash
cd environments/dev
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

#### Check What's Deployed
```bash
terraform state list
terraform show
```

#### Add New IAM Policy
Edit `main.tf` and add to `policies` map:
```hcl
"my-new-policy" = {
  description = "Description of policy"
  policy_document = { /* JSON policy */ }
}
```

### Troubleshooting

#### Test Cross-Account Access
```bash
aws sts assume-role \
  --role-arn arn:aws:iam::ACCOUNT-ID:role/TerraformCrossAccountRole \
  --role-session-name test \
  --external-id your-external-id
```

#### Check Backend Status
```bash
aws s3 ls s3://my-company-dev-terraform-state/
aws dynamodb describe-table --table-name my-company-dev-terraform-locks
```

#### Force Unlock State (Emergency)
```bash
terraform force-unlock LOCK_ID
```

## File Locations

- **Main config**: `environments/{env}/main.tf`
- **Variables**: `environments/{env}/terraform.tfvars`
- **Backend config**: `environments/{env}/backend-distributed.hcl`
- **Setup script**: `shared/backend/setup-distributed-backend.sh`

## Account Structure

```
Management Account → Runs Terraform
    ↓ (assumes roles)
Dev Account     → [S3 State] + [DynamoDB Locks] + [IAM Resources]
Staging Account → [S3 State] + [DynamoDB Locks] + [IAM Resources]
Prod Account    → [S3 State] + [DynamoDB Locks] + [IAM Resources]
```

## Security Checklist

- [ ] External ID configured and unique
- [ ] Cross-account roles have minimal permissions
- [ ] State buckets are encrypted
- [ ] Each account has isolated state
- [ ] Role assumption tested from management account