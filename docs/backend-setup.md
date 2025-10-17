# Terraform Backend Configuration with S3 Native Locking

This project uses S3 for both state storage and state locking, eliminating the need for a separate DynamoDB table.

## S3 Native State Locking

AWS now supports native state locking directly in S3 when versioning is enabled on the bucket. This simplifies the backend configuration and reduces infrastructure overhead.

### Requirements

- S3 bucket with versioning enabled
- Server-side encryption (recommended)
- Public access blocked (security best practice)

### Benefits

- **Simplified setup**: No DynamoDB table required
- **Cost reduction**: Eliminates DynamoDB charges for state locking
- **Better integration**: Native S3 functionality
- **Improved reliability**: Built-in S3 consistency guarantees

## Setup Instructions

### 1. Create and Configure S3 Bucket

Use the provided script to set up a properly configured bucket:

```bash
./scripts/setup-state-bucket.sh my-terraform-state-bucket us-east-1
```

Or manually create the bucket with these configurations:
- **Versioning**: Enabled (required for state locking)
- **Encryption**: AES256 or KMS
- **Public Access**: Blocked
- **Bucket Policy**: Enforce HTTPS connections

### 2. Environment-Specific Backend Configurations

Each environment has its own backend configuration file:

```
backend/
├── dev.hcl    # Development environment
├── qa.hcl     # QA/Staging environment
└── prod.hcl   # Production environment
```

### 3. Initialize Terraform

Initialize with environment-specific backend:

```bash
# Development
terraform init -backend-config="backend/dev.hcl"

# QA
terraform init -backend-config="backend/qa.hcl"

# Production
terraform init -backend-config="backend/prod.hcl"
```

### 4. Switch Between Environments

When switching environments, reconfigure the backend:

```bash
terraform init -backend-config="backend/prod.hcl" -reconfigure
```

## Backend Configuration Files

### Structure

Each `.hcl` file contains:

```hcl
bucket  = "your-terraform-state-bucket"
key     = "iam-management/ENV/terraform.tfstate"
region  = "us-east-1"
encrypt = true
```

### Environment Isolation

State files are isolated by environment using different keys:
- Development: `iam-management/dev/terraform.tfstate`
- QA: `iam-management/qa/terraform.tfstate`
- Production: `iam-management/prod/terraform.tfstate`

## Migration from DynamoDB

If migrating from DynamoDB-based locking:

1. **Update backend configuration**: Remove `dynamodb_table` parameter
2. **Enable versioning**: Ensure S3 bucket has versioning enabled
3. **Reinitialize**: Run `terraform init -reconfigure`
4. **Clean up**: Optionally remove old DynamoDB table

## Troubleshooting

### State Locking Issues

If you encounter state locking issues:

1. **Verify versioning**: Ensure S3 bucket versioning is enabled
2. **Check permissions**: Verify IAM permissions for S3 operations
3. **Force unlock**: If needed, use `terraform force-unlock`

### Backend Migration

When changing backend configuration:

```bash
# Always use -reconfigure when changing backend settings
terraform init -backend-config="backend/new-env.hcl" -reconfigure
```

## Security Considerations

- **Encryption**: Always enable server-side encryption
- **Access Control**: Use IAM policies to restrict state file access
- **Versioning**: Keep enabled for state locking and history
- **HTTPS Only**: Enforce secure transport with bucket policies
- **Cross-Account**: Consider separate buckets for production isolation