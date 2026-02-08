output "s3_bucket_name" {
  value       = aws_s3_bucket.terraform_state.id
  description = "S3 bucket name for Terraform state storage"
}

output "dynamodb_table_name" {
  value       = aws_dynamodb_table.terraform_locks.name
  description = "DynamoDB table name for state locking"
}
