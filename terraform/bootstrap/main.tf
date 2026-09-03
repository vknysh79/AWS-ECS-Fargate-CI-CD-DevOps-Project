terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# S3 Bucket for Storing Terraform Remote State
resource "aws_s3_bucket" "terraform_state" {
  bucket        = var.bucket_name
  force_destroy = false

  tags = {
    Name        = var.bucket_name
    Environment = "global"
    ManagedBy   = "Terraform"
  }
}

# Enable S3 Bucket Versioning for State History and Rollback
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side Encryption Configuration for Security (AES256)
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block Public Access to State Bucket
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enforce TLS/HTTPS Connections & Strict Access via S3 Bucket Policy
resource "aws_s3_bucket_policy" "enforce_tls_and_strict_access" {
  bucket = aws_s3_bucket.terraform_state.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceTLSRequestsOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# DynamoDB Table for Terraform State Locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = var.dynamodb_table_name
    Environment = "global"
    ManagedBy   = "Terraform"
  }
}

# ==============================================================================
# IAM ROLES & POLICIES FOR STRICT TERRAFORM STATE & LOCK ACCESS
# ==============================================================================

locals {
  environments = ["dev", "qa", "stage", "production"]
}

# Per-Environment IAM Roles for Scoped State Access
resource "aws_iam_role" "terraform_env_role" {
  for_each = toset(local.environments)
  name     = "terraform-state-role-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "terraform-state-role-${each.key}"
    Environment = each.key
    ManagedBy   = "Terraform"
  }
}

# Strict Scoped IAM Policy per Environment (Least Privilege)
resource "aws_iam_policy" "terraform_env_state_policy" {
  for_each    = toset(local.environments)
  name        = "terraform-state-policy-${each.key}"
  description = "Strict IAM Policy for Terraform state access in ${each.key} environment"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3ListBucketForEnv"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = aws_s3_bucket.terraform_state.arn
        Condition = {
          StringLike = {
            "s3:prefix" = [
              "ecs-fargate/${each.key}/*",
              "ecs-fargate/${each.key}"
            ]
          }
        }
      },
      {
        Sid    = "AllowS3ObjectActionsForEnv"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.terraform_state.arn}/ecs-fargate/${each.key}/*"
      },
      {
        Sid    = "AllowDynamoDBLocking"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = aws_dynamodb_table.terraform_locks.arn
      }
    ]
  })
}

# Attach Scoped Policy to Environment IAM Role
resource "aws_iam_role_policy_attachment" "terraform_env_policy_attach" {
  for_each   = toset(local.environments)
  role       = aws_iam_role.terraform_env_role[each.key].name
  policy_arn = aws_iam_policy.terraform_env_state_policy[each.key].arn
}
