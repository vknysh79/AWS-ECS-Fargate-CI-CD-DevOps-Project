variable "aws_region" {
  type        = string
  description = "AWS Region for backend state infrastructure"
  default     = "us-east-1"
}

variable "bucket_name" {
  type        = string
  description = "S3 bucket name for storing Terraform remote state files"
  default     = "devops-terraform-state-bucket-prod"
}

variable "dynamodb_table_name" {
  type        = string
  description = "DynamoDB table name for Terraform state locking"
  default     = "devops-terraform-state-locks"
}
