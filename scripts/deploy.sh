#!/bin/bash

# Deployment script for environment-specific IAM resources
# Usage: ./scripts/deploy.sh <environment>
# Example: ./scripts/deploy.sh dev

set -e

ENVIRONMENT=${1:-""}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [ -z "$ENVIRONMENT" ]; then
    echo "Usage: $0 <environment>"
    echo "Available environments: dev, qa, prod"
    exit 1
fi

cd "$PROJECT_DIR"

# Initialize terraform with environment-specific backend
echo "Initializing Terraform with $ENVIRONMENT backend configuration..."
terraform init -backend-config="backend/$ENVIRONMENT.hcl" -reconfigure

case $ENVIRONMENT in
    "dev")
        echo "Deploying to Development environment..."
        terraform apply -var-file="examples/dev.tfvars" -auto-approve
        ;;
    "qa") 
        echo "Deploying to QA environment..."
        terraform apply -var-file="examples/qa.tfvars" -auto-approve
        ;;
    "prod")
        echo "Deploying to Production environment..."
        echo "WARNING: This will deploy to PRODUCTION!"
        read -p "Are you sure? (yes/no): " -r
        if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            terraform apply -var-file="examples/prod.tfvars" -auto-approve
        else
            echo "Production deployment cancelled."
            exit 1
        fi
        ;;
    *)
        echo "Invalid environment: $ENVIRONMENT"
        echo "Available environments: dev, qa, prod"
        exit 1
        ;;
esac

echo "Deployment completed successfully!"