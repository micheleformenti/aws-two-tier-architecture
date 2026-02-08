output "alb_dns_name" {
  value       = module.app.alb_dns_name
  description = "DNS name of the load balancer."
}

output "alb_https_url" {
  value       = module.app.alb_https_url
  description = "HTTPS URL to access the application"
}

output "ecr_repository_url" {
  value       = module.app.ecr_repository_url
  description = "ECR repository URL for pushing Docker images"
}

output "ecs_cluster_name" {
  value       = module.app.ecs_cluster_name
  description = "ECS cluster name"
}

output "ecs_service_name" {
  value       = module.app.ecs_service_name
  description = "ECS service name"
}

output "rds_endpoint" {
  value       = module.app.rds_endpoint
  description = "RDS database endpoint (address:port)"
  sensitive   = true
}

output "rds_database_name" {
  value       = module.app.rds_database_name
  description = "RDS database name"
}

output "cloudwatch_log_group" {
  value       = module.app.cloudwatch_log_group
  description = "CloudWatch log group for ECS container logs"
}

output "github_actions_role_arn" {
  value       = module.app.github_actions_role_arn
  description = "ARN of the IAM role for GitHub Actions to assume. Use this in your GitHub workflow with aws-actions/configure-aws-credentials."
}

output "aws_account_id" {
  value       = module.app.aws_account_id
  description = "AWS Account ID"
}
