# Terraform Execution IAM Policies

This directory contains comprehensive IAM policy documents that grant Terraform the necessary permissions to manage AWS resources.

## Policy Files

### 1. `terraform-execution-policy.json`
**Complete permissions for development and non-production environments**

- **S3**: Full bucket and object management
- **EC2**: Instance lifecycle, images, key pairs, tagging
- **EBS**: Volume and snapshot management
- **VPC**: VPC, subnet, routing, NAT gateway management
- **Security Groups**: Creation, modification, rule management
- **IAM**: Role, policy, instance profile management
- **ELB/ALB**: Load balancer and target group management
- **API Gateway**: REST and HTTP API management (v1 and v2)
- **Supporting Services**: ACM, Route53, CloudWatch, CloudWatch Logs

### 2. `terraform-execution-policy-prod.json`
**Restricted permissions for production environments**

Key differences from the standard policy:
- **S3 Resources**: Limited to `prod-*` and `production-*` buckets only
- **EC2 Management**: Conditional on region and environment tags
- **IAM Resources**: Restricted to `prod-*` and `production-*` resources
- **Region Restrictions**: Limited to `us-east-1` and `us-west-2`
- **Explicit Denies**: Blocks dangerous actions like user/group management
- **Reduced Permissions**: No Route53, limited CloudWatch access

## Usage

### Attach to Terraform Execution Role

1. **Create IAM Role** for Terraform execution
2. **Attach Policy** using one of the provided JSON documents
3. **Configure Cross-Account Trust** if needed

#### Example Role Creation (AWS CLI)

```bash
# Create role
aws iam create-role --role-name TerraformExecutionRole-Dev \
  --assume-role-policy-document file://trust-policy.json

# Attach policy
aws iam put-role-policy --role-name TerraformExecutionRole-Dev \
  --policy-name TerraformExecutionPolicy \
  --policy-document file://terraform-execution-policy.json
```

### Trust Policy Example

Create a `trust-policy.json` for the role:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::MANAGEMENT-ACCOUNT-ID:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "terraform-execution-unique-id"
        }
      }
    }
  ]
}
```

## Environment-Specific Recommendations

### Development Environment
- Use: `terraform-execution-policy.json`
- Allows: Full resource management for rapid development
- Risk: Low (non-production environment)

### QA/Staging Environment
- Use: `terraform-execution-policy.json` with additional conditions
- Consider: Adding resource tagging requirements
- Risk: Medium (pre-production testing)

### Production Environment
- Use: `terraform-execution-policy-prod.json`
- Requires: Strict naming conventions (`prod-*` resources)
- Includes: Explicit deny statements for dangerous actions
- Risk: High (production impact)

## Security Best Practices

### 1. Least Privilege
- Use production policy for production accounts
- Add conditions based on resource tags
- Regularly audit and remove unused permissions

### 2. Resource Naming
- Use consistent naming conventions
- Leverage conditions to enforce naming patterns
- Example: `prod-*`, `dev-*`, `staging-*` prefixes

### 3. Cross-Account Access
- Use external ID in trust policies
- Rotate external IDs periodically
- Monitor cross-account role usage

### 4. Monitoring and Auditing
- Enable CloudTrail for API calls
- Set up CloudWatch alerts for policy violations
- Regularly review IAM access patterns

## Policy Customization

### Adding Services
To add support for additional AWS services:

1. **Identify Required Actions**: Check Terraform provider documentation
2. **Add Permissions**: Include necessary actions in new statement
3. **Apply Conditions**: Add resource or request conditions as needed
4. **Test Thoroughly**: Verify in development environment first

### Resource Restrictions
Add conditions to limit resource access:

```json
{
  "Condition": {
    "StringEquals": {
      "aws:RequestedRegion": ["us-east-1", "us-west-2"]
    },
    "StringLike": {
      "aws:ResourceTag/Environment": "prod*"
    }
  }
}
```

### Common Conditions
- **Region restriction**: `aws:RequestedRegion`
- **Tag-based access**: `aws:ResourceTag/TagKey`
- **Request time**: `aws:CurrentTime`
- **IP address**: `aws:SourceIp`
- **MFA required**: `aws:MultiFactorAuthPresent`

## Troubleshooting

### Permission Denied Errors
1. **Check Action**: Verify the required action is in the policy
2. **Check Resource**: Ensure resource ARN matches policy conditions
3. **Check Conditions**: Verify all conditions are met
4. **Check Deny Statements**: Ensure no explicit denies block the action

### Common Issues
- **S3 bucket restrictions**: Check bucket naming in production policy
- **IAM resource limits**: Verify resource ARNs match naming patterns
- **Regional restrictions**: Ensure operations in allowed regions
- **Tag requirements**: Check resource tagging compliance

## Testing

### Validation Commands
```bash
# Test policy syntax
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT:role/TerraformExecutionRole \
  --action-names s3:CreateBucket \
  --resource-arns arn:aws:s3:::test-bucket

# Dry run with Terraform
terraform plan -var-file="examples/dev.tfvars"
```

### Policy Simulator
Use AWS IAM Policy Simulator to test permissions before deployment:
1. Go to IAM Policy Simulator in AWS Console
2. Select role and policy
3. Test specific actions and resources
4. Verify expected results