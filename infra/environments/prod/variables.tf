variable "project" {
  description = "Project/name prefix used for tagging and resource naming"
  type        = string
  default     = "two-tier-app"
}

variable "env" {
  description = "Environment name (e.g. dev, prod) used for tagging and resource naming"
  type        = string
  default     = "prod"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the environment VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Two public subnet CIDRs (AZ1, AZ2)"
  type        = list(string)
  default     = ["10.20.0.0/24", "10.20.1.0/24"]
}

variable "app_subnet_cidrs" {
  description = "Two application/private subnet CIDRs (AZ1, AZ2)"
  type        = list(string)
  default     = ["10.20.10.0/24", "10.20.11.0/24"]
}

variable "db_subnet_cidrs" {
  description = "Two database subnet CIDRs (AZ1, AZ2)"
  type        = list(string)
  default     = ["10.20.20.0/24", "10.20.21.0/24"]
}

variable "db_name" {
  description = "Name of the initial database to create in RDS"
  type        = string
  default     = "app_db"
}

variable "app_port" {
  description = "Application port for the ECS tasks"
  type        = number
  default     = 5000
}

variable "github_org" {
  description = "GitHub organization/owner name"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

# ECS Configuration
variable "ecs_task_cpu" {
  description = "ECS task CPU units (256, 512, 1024, 2048, 4096)"
  type        = string
  default     = "256"
}

variable "ecs_task_memory" {
  description = "ECS task memory in MB (must be valid for the CPU)"
  type        = string
  default     = "512"
}

variable "ecs_desired_count" {
  description = "Desired number of ECS tasks to run"
  type        = number
  default     = 2
}

variable "ecr_image_uri" {
  description = "ECR image URI for the application"
  type        = string
}

# RDS Configuration
variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "Allocated storage for RDS in GB"
  type        = number
  default     = 5
}

variable "db_backup_retention_days" {
  description = "Number of days to retain RDS backups"
  type        = number
  default     = 7
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "secrets_recovery_window_days" {
  description = "AWS Secrets Manager recovery window in days (time before permanent deletion)"
  type        = number
  default     = 0
}

variable "domain_name" {
  description = "Domain name for ALB SSL certificate"
  type        = string
}

variable "route53_zone_name" {
  description = "Route53 hosted zone name"
  type        = string
}

variable "alarm_email" {
  description = "Email address to receive CloudWatch alarm notifications (requires confirmation)"
  type        = string
}

# ECS Auto Scaling Configuration
variable "ecs_max_capacity" {
  description = "Maximum number of ECS tasks for autoscaling"
  type        = number
  default     = 4
}

variable "ecs_cpu_target" {
  description = "Target CPU utilization percentage for autoscaling"
  type        = number
  default     = 85.0
}

variable "ecs_memory_target" {
  description = "Target memory utilization percentage for autoscaling"
  type        = number
  default     = 90.0
}

variable "ecs_scale_out_cooldown" {
  description = "Cooldown period in seconds after scaling out (adding tasks)"
  type        = number
  default     = 300
}

variable "ecs_scale_in_cooldown" {
  description = "Cooldown period in seconds after scaling in (removing tasks)"
  type        = number
  default     = 600
}
