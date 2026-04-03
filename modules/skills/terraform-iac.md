---
name: terraform-iac
description: Write, validate, and manage Terraform infrastructure code with best practices
read_when: "user wants to write Terraform, manage infrastructure as code, provision cloud resources, or work with HCL"
---

# Terraform Infrastructure as Code

Generate and validate Terraform HCL following HashiCorp best practices.

## Project Structure
```
infrastructure/
  main.tf           # Provider config, backend
  variables.tf      # Input variables
  outputs.tf        # Output values
  terraform.tfvars  # Variable values (git-ignored if secrets)
  modules/
    networking/
    compute/
    database/
```

## Core Patterns

### Resource with best practices
```hcl
resource "aws_s3_bucket" "data" {
  bucket = "${var.project}-${var.environment}-data"

  tags = merge(var.common_tags, {
    Name = "${var.project}-data"
  })
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id
  versioning_configuration {
    status = "Enabled"
  }
}
```

### Module pattern
```hcl
module "vpc" {
  source  = "./modules/networking"
  cidr    = var.vpc_cidr
  azs     = var.availability_zones
  project = var.project
  environment = var.environment
}
```

### Variables with validation
```hcl
variable "environment" {
  type        = string
  description = "Deployment environment"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}
```

## Commands
```bash
terraform init          # Initialize, download providers
terraform fmt -check    # Check formatting
terraform validate      # Syntax and reference check
terraform plan -out=plan.tfplan  # Preview changes
terraform apply plan.tfplan      # Apply saved plan
terraform destroy       # Tear down (use with caution)
```

## Hard Rules
1. **Never** hardcode secrets in `.tf` files -- use variables + vault/SSM
2. **Always** use remote state (S3 + DynamoDB lock, Terraform Cloud, etc.)
3. **Pin** provider and module versions: `version = "~> 5.0"`
4. **Tag** every resource with project, environment, owner
5. **Use** `terraform plan` before every `apply` -- review the diff
6. **Separate** state per environment (workspaces or directory-per-env)

## State Management
```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

## Import Existing Resources
```bash
terraform import aws_s3_bucket.data my-existing-bucket
```
