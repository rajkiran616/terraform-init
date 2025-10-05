# Distributed Backend Setup Guide

## Why Distributed State Management?

After careful consideration, **distributed state management (per-account)** is recommended for enterprise multi-account setups for the following reasons:

### 🔒 **Enhanced Security**
- Each account's state is completely isolated
- No cross-account state access required
- Better compliance with data residency requirements
- Reduced attack surface

### 🎯 **Reduced Blast Radius**
- State corruption affects only one account
- Account failures don't impact other environments
- Independent disaster recovery per account
- Easier to troubleshoot and recover

### 🏢 **Better Governance**
- Account teams own their infrastructure state
- Clear responsibility boundaries
- Easier compliance auditing
- No dependencies on central management account

### ⚡ **Improved Performance**
- No cross-account network calls for state operations
- Faster state read/write operations
- Reduced latency

## Implementation Guide

### Step 1: Set up Backend Infrastructure Per Account

For each target account (dev, staging, prod), run:

```bash
cd shared/backend

# Setup backend in development account
./setup-distributed-backend.sh \
  -e dev \
  -r arn:aws:iam::123456789012:role/TerraformCrossAccountRole \
  -x your-external-id \
  -a development

# Setup backend in staging account  
./setup-distributed-backend.sh \
  -e staging \
  -r arn:aws:iam::987654321098:role/TerraformCrossAccountRole \
  -x your-external-id \
  -a staging

# Setup backend in production account
./setup-distributed-backend.sh \
  -e prod \
  -r arn:aws:iam::555666777888:role/TerraformCrossAccountRole \
  -x your-external-id \
  -a production
```

This creates in each account:
- **S3 Bucket**: `{project}-{env}-terraform-state`
- **DynamoDB Table**: `{project}-{env}-terraform-locks`  
- **KMS Key**: For state encryption
- **Backend Config**: `environments/{env}/backend-distributed.hcl`

### Step 2: Migrate to Distributed Backend

For each environment:

```bash
cd environments/dev

# Use the distributed backend configuration
cp main-distributed.tf main.tf

# Initialize with the distributed backend
terraform init -backend-config=backend-distributed.hcl -migrate-state

# Verify the migration
terraform plan
```

### Step 3: Verify the Setup

Check that state is properly isolated:

```bash
# Check dev account state
aws s3 ls s3://my-company-dev-terraform-state/ --profile dev-account

# Check staging account state  
aws s3 ls s3://my-company-staging-terraform-state/ --profile staging-account

# Verify no cross-account access needed
terraform state list
```

## Architecture Comparison

### Before: Centralized State
```
Management Account
├── S3: central-terraform-state
│   ├── environments/dev/terraform.tfstate
│   ├── environments/staging/terraform.tfstate
│   └── environments/prod/terraform.tfstate
└── DynamoDB: central-terraform-locks

Risk: Single point of failure affects all environments
```

### After: Distributed State
```
Dev Account:     S3: dev-terraform-state + DynamoDB: dev-locks
Staging Account: S3: staging-terraform-state + DynamoDB: staging-locks  
Prod Account:    S3: prod-terraform-state + DynamoDB: prod-locks

Benefit: Complete isolation, reduced blast radius
```

## Security Enhancements

Each distributed backend includes:

1. **KMS Encryption**: Account-specific encryption keys
2. **Access Controls**: Only same-account access
3. **Versioning**: Full state history
4. **SSL/TLS**: Encrypted in transit
5. **Point-in-Time Recovery**: DynamoDB PITR enabled

## Cross-Account Data Sharing

When you need to reference resources across accounts:

### Option 1: Data Sources (Recommended)
```hcl
# In staging, reference dev resources
data "aws_iam_role" "dev_role" {
  provider = aws.dev_account
  name     = "dev-lambda-execution-role"
}
```

### Option 2: Parameter Store/Secrets Manager
```hcl
# Export from dev account
resource "aws_ssm_parameter" "shared_role_arn" {
  name  = "/shared/dev/lambda-role-arn"
  type  = "String" 
  value = aws_iam_role.lambda_role.arn
}

# Import in staging account
data "aws_ssm_parameter" "dev_role" {
  name = "/shared/dev/lambda-role-arn"
}
```

### Option 3: Remote State (Limited Use)
```hcl
# Only when absolutely necessary
data "terraform_remote_state" "dev" {
  backend = "s3"
  config = {
    bucket   = "my-company-dev-terraform-state"
    key      = "terraform.tfstate"
    region   = "us-east-1"
    role_arn = "arn:aws:iam::DEV-ACCOUNT:role/TerraformStateReader"
  }
}
```

## Monitoring and Maintenance

### State Health Monitoring
```bash
# Check state bucket replication status
aws s3api get-bucket-versioning --bucket my-company-dev-terraform-state

# Monitor DynamoDB locks
aws dynamodb scan --table-name my-company-dev-terraform-locks --select COUNT
```

### Backup Strategy
```bash
# Automated backup of state files
aws s3 sync s3://my-company-dev-terraform-state s3://backup-bucket/dev/ --include "*.tfstate"
```

### Cost Optimization
- Use S3 Intelligent Tiering for state storage
- Enable DynamoDB on-demand billing
- Regular cleanup of old state versions

## Migration Checklist

- [ ] Set up cross-account roles in each target account
- [ ] Run distributed backend setup for each account
- [ ] Update environment configurations to use distributed backend
- [ ] Migrate existing state using `terraform init -migrate-state`
- [ ] Verify state isolation between accounts
- [ ] Update CI/CD pipelines with new backend configs
- [ ] Test disaster recovery procedures
- [ ] Update team documentation and runbooks

## Troubleshooting

### Common Issues

**State Lock Errors**:
```bash
# Force unlock if needed (use carefully)
terraform force-unlock LOCK_ID
```

**Backend Access Errors**:
- Verify cross-account role permissions
- Check S3 bucket policies
- Confirm KMS key permissions

**Migration Issues**:
- Backup existing state before migration
- Use `-migrate-state` flag carefully
- Verify state integrity after migration

## Best Practices

1. **One Backend Per Account**: Never mix account states
2. **Consistent Naming**: Use predictable bucket/table names
3. **Access Logging**: Enable CloudTrail for all state operations
4. **Regular Backups**: Automate state backup processes
5. **Monitoring**: Set up alerts for state operations
6. **Documentation**: Keep backend configurations documented

This distributed approach provides enterprise-grade security, isolation, and scalability for your multi-account Terraform infrastructure.