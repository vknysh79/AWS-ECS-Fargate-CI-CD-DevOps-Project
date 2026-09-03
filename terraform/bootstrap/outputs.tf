output "s3_bucket_name" {
  description = "Name of the S3 bucket created for Terraform remote state"
  value       = aws_s3_bucket.terraform_state.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket created for Terraform remote state"
  value       = aws_s3_bucket.terraform_state.arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table created for state locking"
  value       = aws_dynamodb_table.terraform_locks.id
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table created for state locking"
  value       = aws_dynamodb_table.terraform_locks.arn
}

output "terraform_environment_role_arns" {
  description = "Map of IAM Role ARNs for strict state file access per environment"
  value       = { for env, role in aws_iam_role.terraform_env_role : env => role.arn }
}
