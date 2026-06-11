# One-off bootstrap for the Terraform state bucket. Uses local state on
# purpose (chicken-and-egg: the backend bucket can't store its own state).
terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project   = "waf-as-code"
      ManagedBy = "terraform"
    }
  }
}

resource "aws_s3_bucket" "tfstate" {
  bucket_prefix = "waf-as-code-tfstate-"
  force_destroy = true # demo only; never on a real state bucket
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "bucket_name" {
  value = aws_s3_bucket.tfstate.bucket
}
