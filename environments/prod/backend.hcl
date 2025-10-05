# Backend configuration for Production environment
bucket         = "my-company-terraform-state"
key            = "environments/prod/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-locks"
encrypt        = true

# Optional: Use assume role if the state bucket is in a different account
# assume_role = {
#   role_arn = "arn:aws:iam::MANAGEMENT-ACCOUNT-ID:role/TerraformStateRole"
# }