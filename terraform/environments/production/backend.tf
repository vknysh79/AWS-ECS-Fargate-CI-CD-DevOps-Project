terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "devops-terraform-state-bucket-prod"
    key            = "ecs-fargate/production/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "devops-terraform-state-locks"
    # role_arn       = "arn:aws:iam::<ACCOUNT_ID>:role/terraform-state-role-production"
  }
}

provider "aws" {
  region = var.aws_region
}
