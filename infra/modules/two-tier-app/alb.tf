resource "aws_lb" "alb" {
  name               = "${var.project}-${var.env}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg_alb.id]
  subnets            = [aws_subnet.public_subnet_az1.id, aws_subnet.public_subnet_az2.id]

  depends_on = [
    aws_s3_bucket_policy.alb_access_logs,
    aws_s3_bucket_public_access_block.alb_access_logs,
    aws_s3_bucket_ownership_controls.alb_access_logs,
  ]

  drop_invalid_header_fields = true

  dynamic "access_logs" {
    for_each = var.enable_alb_access_logs ? [1] : []
    content {
      bucket  = aws_s3_bucket.alb_access_logs[0].id
      prefix  = local.alb_access_logs_prefix
      enabled = true
    }
  }

  tags = {
    Name    = "${var.project}-${var.env}-alb"
    Env     = var.env
    Project = var.project
  }
}

# Get the Route53 zone for your domain
data "aws_route53_zone" "main" {
  name = var.route53_zone_name
}

# SSL Certificate from ACM (requires domain to be managed in Route53)
resource "aws_acm_certificate" "alb_cert" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  tags = {
    Name    = "${var.project}-${var.env}-cert"
    Env     = var.env
    Project = var.project
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Create DNS validation records in Route53
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.alb_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}

# Validate the certificate
resource "aws_acm_certificate_validation" "alb_cert" {
  certificate_arn = aws_acm_certificate.alb_cert.arn

  timeouts {
    create = "5m"
  }

  depends_on = [aws_route53_record.cert_validation]
}

# DNS record pointing domain to ALB
resource "aws_route53_record" "app" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}

# Target Group for ECS tasks, IPs are registered dynamically by ECS control plane
resource "aws_lb_target_group" "ecs_tg" {
  name        = "${var.project}-${var.env}-alb-tg"
  port        = var.app_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.vpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Listener for ALB on port 80 - redirect to HTTPS
resource "aws_lb_listener" "alb_listener_http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Listener for ALB on port 443 (HTTPS) forwarding to ECS target group
resource "aws_lb_listener" "alb_listener_https" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate_validation.alb_cert.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_tg.arn
  }
}
