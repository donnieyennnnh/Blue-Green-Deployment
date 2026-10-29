# providers.tf — Terraform + AWS provider version pins and auth config.
#
# Credentials come from the named AWS CLI profile (set up in Phase 0 via
#   aws configure --profile blue-green
# ). This keeps secrets out of .tf files and out of .tfvars.
#
# State backend: local for now. To migrate to S3 later, uncomment the
# `backend "s3"` block below, run `terraform init -migrate-state`, and
# commit the change.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # backend "s3" {
  #   bucket         = "bobross-gallery-tfstate"
  #   key            = "terraform.tfstate"
  #   region         = "ap-southeast-1"
  #   dynamodb_table = "bobross-gallery-tflock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
