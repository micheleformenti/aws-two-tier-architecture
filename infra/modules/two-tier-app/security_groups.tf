# Security Group for Application Load Balancer (ALB) 
resource "aws_security_group" "sg_alb" {
  name        = "sg_alb"
  description = "Allows connections to ALB on port 443"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name    = "${var.project}-${var.env}-sg_alb"
    Env     = var.env
    Project = var.project
  }
}

# Allow HTTP traffic to ALB from anywhere
resource "aws_vpc_security_group_ingress_rule" "allow_http_ipv4" {
  security_group_id = aws_security_group.sg_alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

# Allow HTTPS traffic to ALB from anywhere
resource "aws_vpc_security_group_ingress_rule" "allow_https_ipv4" {
  security_group_id = aws_security_group.sg_alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

# Allow ALB to forward traffic to ECS tasks on the application port
resource "aws_vpc_security_group_egress_rule" "allow_app_traffic_ipv4" {
  security_group_id            = aws_security_group.sg_alb.id
  referenced_security_group_id = aws_security_group.sg_tasks.id
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
}

# Security Group for ECS Tasks
resource "aws_security_group" "sg_tasks" {
  name        = "sg_tasks"
  description = "Allows from ALB to ECS tasks on port var.app_port"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name    = "${var.project}-${var.env}-sg_tasks"
    Env     = var.env
    Project = var.project
  }
}

# Allow ALB to connect to ECS tasks on the application port
resource "aws_vpc_security_group_ingress_rule" "allow_alb_to_tasks_ipv4" {
  security_group_id            = aws_security_group.sg_tasks.id
  referenced_security_group_id = aws_security_group.sg_alb.id
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
}

data "aws_prefix_list" "s3" {
  name = "com.amazonaws.${data.aws_region.current.id}.s3"
}

# Tight task egress (no NAT):
# - HTTPS to Interface VPC Endpoints (PrivateLink)
# - HTTPS to S3 (via S3 Gateway VPC Endpoint route)
# - DNS to VPC resolver (within the VPC)
# - Postgres to RDS
resource "aws_vpc_security_group_egress_rule" "allow_tasks_to_vpc_endpoints_https" {
  security_group_id            = aws_security_group.sg_tasks.id
  referenced_security_group_id = aws_security_group.sg_vpc_endpoints.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}

resource "aws_vpc_security_group_egress_rule" "allow_tasks_to_s3_https" {
  security_group_id = aws_security_group.sg_tasks.id
  prefix_list_id    = data.aws_prefix_list.s3.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "allow_tasks_dns_udp" {
  security_group_id = aws_security_group.sg_tasks.id
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "udp"
  from_port         = 53
  to_port           = 53
}

resource "aws_vpc_security_group_egress_rule" "allow_tasks_dns_tcp" {
  security_group_id = aws_security_group.sg_tasks.id
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "tcp"
  from_port         = 53
  to_port           = 53
}

resource "aws_vpc_security_group_egress_rule" "allow_tasks_to_rds_postgres" {
  security_group_id            = aws_security_group.sg_tasks.id
  referenced_security_group_id = aws_security_group.sg_rds.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

# Security group for Interface VPC Endpoints (PrivateLink)
resource "aws_security_group" "sg_vpc_endpoints" {
  name        = "sg_vpc_endpoints"
  description = "Allows private subnets to reach AWS services via Interface VPC Endpoints"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name    = "${var.project}-${var.env}-sg_vpc_endpoints"
    Env     = var.env
    Project = var.project
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_tasks_to_vpc_endpoints_https" {
  security_group_id            = aws_security_group.sg_vpc_endpoints.id
  referenced_security_group_id = aws_security_group.sg_tasks.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}

# Egress from the endpoint ENIs to the VPC is not required; responses are stateful.
# We still allow egress to the VPC CIDR to avoid surprises with AWS-managed flows.
resource "aws_vpc_security_group_egress_rule" "allow_vpc_endpoints_egress_to_vpc" {
  security_group_id = aws_security_group.sg_vpc_endpoints.id
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "-1"
}

# Security Group for RDS Instance
resource "aws_security_group" "sg_rds" {
  name        = "sg_rds"
  description = "Allows from tasks to RDS on port 5432"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name    = "${var.project}-${var.env}-sg_rds"
    Env     = var.env
    Project = var.project
  }
}

# Allow ECS tasks to connect to RDS on port 5432
resource "aws_vpc_security_group_ingress_rule" "allow_tasks_to_rds_ipv4" {
  security_group_id            = aws_security_group.sg_rds.id
  referenced_security_group_id = aws_security_group.sg_tasks.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}
