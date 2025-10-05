# Backend configuration for Development environment
bucket         = "my-company-terraform-state"
key            = "environments/dev/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-locks"
encrypt        = true

# Optional: Use assume role if the state bucket is in a different account
# assume_role = {
#   role_arn = "arn:aws:iam::MANAGEMENT-ACCOUNT-ID:role/TerraformStateRole"
# }