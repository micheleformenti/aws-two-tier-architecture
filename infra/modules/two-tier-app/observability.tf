locals {
  alb_access_logs_prefix = "${var.project}-${var.env}-alb"

  # Keep bucket name globally-unique by including AWS account + region.
  alb_access_logs_bucket_name = lower("${var.project}-${var.env}-alb-logs-${data.aws_caller_identity.current.account_id}-${var.region}")
}

# Legacy ELB/ALB log-delivery principal (region-specific). Keeping this alongside the
# modern service principal improves compatibility when AWS validates logging.
data "aws_elb_service_account" "main" {}

# Alarm notifications (SNS)
resource "aws_sns_topic" "alarms" {
  count = var.enable_cloudwatch_alarms ? 1 : 0
  name  = "${var.project}-${var.env}-alarms"

  tags = {
    Name    = "${var.project}-${var.env}-alarms"
    Env     = var.env
    Project = var.project
  }
}

resource "aws_sns_topic_subscription" "alarm_email" {
  count     = var.enable_cloudwatch_alarms ? 1 : 0
  topic_arn = aws_sns_topic.alarms[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# ALB access logs (S3)
resource "aws_s3_bucket" "alb_access_logs" {
  count  = var.enable_alb_access_logs ? 1 : 0
  bucket = local.alb_access_logs_bucket_name

  tags = {
    Name    = "${var.project}-${var.env}-alb-access-logs"
    Env     = var.env
    Project = var.project
  }
}

resource "aws_s3_bucket_public_access_block" "alb_access_logs" {
  count  = var.enable_alb_access_logs ? 1 : 0
  bucket = aws_s3_bucket.alb_access_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "alb_access_logs" {
  count  = var.enable_alb_access_logs ? 1 : 0
  bucket = aws_s3_bucket.alb_access_logs[0].id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_access_logs" {
  count  = var.enable_alb_access_logs ? 1 : 0
  bucket = aws_s3_bucket.alb_access_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "alb_access_logs" {
  count  = var.enable_alb_access_logs ? 1 : 0
  bucket = aws_s3_bucket.alb_access_logs[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "alb_access_logs" {
  count  = var.enable_alb_access_logs ? 1 : 0
  bucket = aws_s3_bucket.alb_access_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSLogDeliveryAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "logdelivery.elasticloadbalancing.amazonaws.com"
          AWS     = data.aws_elb_service_account.main.arn
        }
        Action   = ["s3:GetBucketAcl", "s3:GetBucketLocation"]
        Resource = aws_s3_bucket.alb_access_logs[0].arn
      },
      {
        Sid    = "AWSLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          Service = "logdelivery.elasticloadbalancing.amazonaws.com"
          AWS     = data.aws_elb_service_account.main.arn
        }
        Action   = "s3:PutObject"
        Resource = [
          "${aws_s3_bucket.alb_access_logs[0].arn}/${local.alb_access_logs_prefix}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
          "${aws_s3_bucket.alb_access_logs[0].arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
        ]
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# CloudWatch alarms
locals {
  cw_alarm_actions = var.enable_cloudwatch_alarms ? [aws_sns_topic.alarms[0].arn] : []
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${var.project}-${var.env}-alb-target-5xx"
  alarm_description   = "Target 5XX responses are non-zero"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  period              = 60
  statistic           = "Sum"
  threshold           = 0

  namespace   = "AWS/ApplicationELB"
  metric_name = "HTTPCode_Target_5XX_Count"

  dimensions = {
    LoadBalancer = aws_lb.alb.arn_suffix
    TargetGroup  = aws_lb_target_group.ecs_tg.arn_suffix
  }

  treat_missing_data = "notBreaching"
  alarm_actions      = local.cw_alarm_actions
  ok_actions         = local.cw_alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "alb_latency" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${var.project}-${var.env}-alb-target-response-time"
  alarm_description   = "ALB target response time is high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  period              = 60
  statistic           = "Average"
  threshold           = var.alb_target_response_time_alarm_threshold_seconds

  namespace   = "AWS/ApplicationELB"
  metric_name = "TargetResponseTime"

  dimensions = {
    LoadBalancer = aws_lb.alb.arn_suffix
    TargetGroup  = aws_lb_target_group.ecs_tg.arn_suffix
  }

  treat_missing_data = "notBreaching"
  alarm_actions      = local.cw_alarm_actions
  ok_actions         = local.cw_alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "alb_healthy_hosts" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${var.project}-${var.env}-alb-healthy-hosts"
  alarm_description   = "Healthy targets are below desired count"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  period              = 60
  statistic           = "Average"
  threshold           = var.ecs_desired_count

  namespace   = "AWS/ApplicationELB"
  metric_name = "HealthyHostCount"

  dimensions = {
    LoadBalancer = aws_lb.alb.arn_suffix
    TargetGroup  = aws_lb_target_group.ecs_tg.arn_suffix
  }

  treat_missing_data = "breaching"
  alarm_actions      = local.cw_alarm_actions
  ok_actions         = local.cw_alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${var.project}-${var.env}-ecs-cpu-high"
  alarm_description   = "ECS service CPU is high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  period              = 60
  statistic           = "Average"
  threshold           = var.ecs_cpu_alarm_threshold_percent

  namespace   = "AWS/ECS"
  metric_name = "CPUUtilization"
  dimensions = {
    ClusterName = aws_ecs_cluster.ecs_cluster.name
    ServiceName = aws_ecs_service.ecs_service.name
  }

  treat_missing_data = "notBreaching"
  alarm_actions      = local.cw_alarm_actions
  ok_actions         = local.cw_alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${var.project}-${var.env}-ecs-memory-high"
  alarm_description   = "ECS service memory is high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  period              = 60
  statistic           = "Average"
  threshold           = var.ecs_memory_alarm_threshold_percent

  namespace   = "AWS/ECS"
  metric_name = "MemoryUtilization"
  dimensions = {
    ClusterName = aws_ecs_cluster.ecs_cluster.name
    ServiceName = aws_ecs_service.ecs_service.name
  }

  treat_missing_data = "notBreaching"
  alarm_actions      = local.cw_alarm_actions
  ok_actions         = local.cw_alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${var.project}-${var.env}-rds-cpu-high"
  alarm_description   = "RDS CPU is high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  period              = 60
  statistic           = "Average"
  threshold           = var.rds_cpu_alarm_threshold_percent

  namespace   = "AWS/RDS"
  metric_name = "CPUUtilization"
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.rds.identifier
  }

  treat_missing_data = "notBreaching"
  alarm_actions      = local.cw_alarm_actions
  ok_actions         = local.cw_alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage_low" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${var.project}-${var.env}-rds-free-storage-low"
  alarm_description   = "RDS free storage is low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  period              = 300
  statistic           = "Average"
  threshold           = var.rds_free_storage_alarm_threshold_bytes

  namespace   = "AWS/RDS"
  metric_name = "FreeStorageSpace"
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.rds.identifier
  }

  treat_missing_data = "notBreaching"
  alarm_actions      = local.cw_alarm_actions
  ok_actions         = local.cw_alarm_actions
}

# CloudWatch dashboard
resource "aws_cloudwatch_dashboard" "main" {
  count          = var.enable_cloudwatch_dashboard ? 1 : 0
  dashboard_name = "${var.project}-${var.env}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 24
        height = 6
        properties = {
          region = var.region
          title  = "ALB: Requests / 5XX / Latency"
          view   = "timeSeries"
          stat   = "Sum"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.alb.arn_suffix, "TargetGroup", aws_lb_target_group.ecs_tg.arn_suffix, { "label" = "Requests" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", aws_lb.alb.arn_suffix, "TargetGroup", aws_lb_target_group.ecs_tg.arn_suffix, { "label" = "Target 5XX" }],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.alb.arn_suffix, "TargetGroup", aws_lb_target_group.ecs_tg.arn_suffix, { "label" = "TargetResponseTime", "stat" = "Average" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 24
        height = 6
        properties = {
          region = var.region
          title  = "ECS Service: CPU / Memory"
          view   = "timeSeries"
          stat   = "Average"
          period = 60
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.ecs_cluster.name, "ServiceName", aws_ecs_service.ecs_service.name, { "label" = "CPU %" }],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", aws_ecs_cluster.ecs_cluster.name, "ServiceName", aws_ecs_service.ecs_service.name, { "label" = "Mem %" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        properties = {
          region = var.region
          title  = "RDS: CPU / Connections / Free storage"
          view   = "timeSeries"
          stat   = "Average"
          period = 60
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.rds.identifier, { "label" = "CPU %" }],
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", aws_db_instance.rds.identifier, { "label" = "Connections" }],
            ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", aws_db_instance.rds.identifier, { "label" = "FreeStorageBytes" }]
          ]
        }
      }
    ]
  })
}
