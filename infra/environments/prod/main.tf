module "app" {
  source = "../../modules/two-tier-app"

  project = var.project
  env     = var.env
  region  = var.region

  vpc_cidr = var.vpc_cidr

  public_subnet_cidrs = var.public_subnet_cidrs
  app_subnet_cidrs    = var.app_subnet_cidrs
  db_subnet_cidrs     = var.db_subnet_cidrs

  db_name  = var.db_name
  app_port = var.app_port

  github_org  = var.github_org
  github_repo = var.github_repo

  ecs_task_cpu      = var.ecs_task_cpu
  ecs_task_memory   = var.ecs_task_memory
  ecs_desired_count = var.ecs_desired_count
  ecs_max_capacity  = var.ecs_max_capacity
  ecs_cpu_target    = var.ecs_cpu_target
  ecs_memory_target = var.ecs_memory_target
  ecs_scale_out_cooldown = var.ecs_scale_out_cooldown
  ecs_scale_in_cooldown  = var.ecs_scale_in_cooldown

  ecr_image_uri = var.ecr_image_uri

  rds_instance_class        = var.rds_instance_class
  rds_allocated_storage     = var.rds_allocated_storage
  db_backup_retention_days  = var.db_backup_retention_days

  log_retention_days            = var.log_retention_days
  secrets_recovery_window_days  = var.secrets_recovery_window_days

  domain_name       = var.domain_name
  route53_zone_name = var.route53_zone_name

  alarm_email = var.alarm_email
}
