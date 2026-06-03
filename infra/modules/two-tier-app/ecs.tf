# Data source to get current AWS region
data "aws_region" "current" {}

# ECS Cluster to run the application tasks
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.project}-${var.env}-ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# ECS Task Definition defining the container to run
resource "aws_ecs_task_definition" "ecs_task" {
  family                   = "${var.project}-${var.env}-task"
  network_mode             = "awsvpc"    # Required for Fargate
  requires_compatibilities = ["FARGATE"] # Using Fargate (not EC2)
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn # For ECR pulls, CloudWatch logs

  container_definitions = jsonencode([
    {
      name      = "${var.project}-${var.env}"
      image     = var.ecr_image_uri
      essential = true
      portMappings = [
        {
          containerPort = var.app_port
          hostPort      = var.app_port
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      environment = [
        {
          name  = "DB_HOST"
          value = split(":", aws_db_instance.rds.endpoint)[0]
        },
        {
          name  = "DB_NAME"
          value = var.db_name
        },
        {
          name  = "DB_USER"
          value = "postgres"
        }
      ]
      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = aws_secretsmanager_secret.db_password.arn
        },
        {
          name      = "SECRET_KEY"
          valueFrom = aws_secretsmanager_secret.flask_secret_key.arn
        }
      ]
    }
  ])

  tags = {
    Name = "${var.project}-${var.env}-task"
  }
}

# ECS Service to run and maintain desired number of task instances
resource "aws_ecs_service" "ecs_service" {
  name            = "${var.project}-${var.env}-ecs-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.ecs_task.arn
  desired_count   = var.ecs_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.app_subnet_az1.id, aws_subnet.app_subnet_az2.id]
    security_groups  = [aws_security_group.sg_tasks.id]
    assign_public_ip = false # Tasks in private subnets
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_tg.arn
    container_name   = "${var.project}-${var.env}"
    container_port   = var.app_port
  }

  depends_on = [aws_lb_listener.alb_listener_http]

  lifecycle {
    ignore_changes = [
      task_definition,
    ]
  }

  tags = {
    Name = "${var.project}-${var.env}-service"
  }
}

# Auto Scaling Target for ECS Service
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = var.ecs_max_capacity
  min_capacity       = var.ecs_desired_count
  resource_id        = "service/${aws_ecs_cluster.ecs_cluster.name}/${aws_ecs_service.ecs_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Target Tracking Scaling Policy - Scale on CPU utilization
resource "aws_appautoscaling_policy" "ecs_policy_cpu" {
  name               = "${var.project}-${var.env}-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = var.ecs_cpu_target
    scale_in_cooldown  = var.ecs_scale_in_cooldown
    scale_out_cooldown = var.ecs_scale_out_cooldown
  }
}

# Target Tracking Scaling Policy - Scale on Memory utilization
resource "aws_appautoscaling_policy" "ecs_policy_memory" {
  name               = "${var.project}-${var.env}-memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value       = var.ecs_memory_target
    scale_in_cooldown  = var.ecs_scale_in_cooldown
    scale_out_cooldown = var.ecs_scale_out_cooldown
  }
}

# CloudWatch Logs to see container output
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${var.project}-${var.env}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project}-${var.env}-logs"
  }
}
