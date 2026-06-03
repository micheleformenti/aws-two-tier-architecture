output "alb_dns_name" {
  value       = aws_lb.alb.dns_name
  description = "DNS name of the load balancer."
}

output "alb_https_url" {
  value       = "https://${var.domain_name}"
  description = "HTTPS URL to access the application"
}

output "ecr_repository_url" {
  value       = aws_ecr_repository.app_repo.repository_url
  description = "ECR repository URL for pushing Docker images"
}

output "ecs_cluster_name" {
  value       = aws_ecs_cluster.ecs_cluster.name
  description = "ECS cluster name"
}

output "ecs_service_name" {
  value       = aws_ecs_service.ecs_service.name
  description = "ECS service name"
}

output "ecs_task_execution_role_arn" {
  value       = aws_iam_role.ecs_task_execution_role.arn
  description = "ECS task execution role ARN used by task definition revisions"
}

output "rds_endpoint" {
  value       = aws_db_instance.rds.endpoint
  description = "RDS database endpoint (address:port)"
  sensitive   = true
}

output "rds_database_name" {
  value       = aws_db_instance.rds.db_name
  description = "RDS database name"
}

output "cloudwatch_log_group" {
  value       = aws_cloudwatch_log_group.ecs_logs.name
  description = "CloudWatch log group for ECS container logs"
}

output "alb_access_logs_bucket" {
  value       = var.enable_alb_access_logs ? aws_s3_bucket.alb_access_logs[0].bucket : null
  description = "S3 bucket storing ALB access logs (if enabled)"
}

output "cloudwatch_dashboard_name" {
  value       = var.enable_cloudwatch_dashboard ? aws_cloudwatch_dashboard.main[0].dashboard_name : null
  description = "CloudWatch dashboard name (if enabled)"
}

output "alarm_sns_topic_arn" {
  value       = var.enable_cloudwatch_alarms ? aws_sns_topic.alarms[0].arn : null
  description = "SNS topic ARN for alarm notifications (created when alarms are enabled)"
}

output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions_ecr_role.arn
  description = "ARN of the IAM role for GitHub Actions to assume. Use this in your GitHub workflow with aws-actions/configure-aws-credentials."
}

output "aws_account_id" {
  value       = data.aws_caller_identity.current.account_id
  description = "AWS Account ID"
}
