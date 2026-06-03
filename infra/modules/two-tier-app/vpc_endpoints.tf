# VPC Endpoints to avoid NAT gateways for AWS service access from private subnets

locals {
  # Interface endpoints required for ECS Fargate tasks in private subnets:
  # - ECR image pulls: ecr.api, ecr.dkr (+ S3 gateway endpoint)
  # - CloudWatch logs: logs
  # - Secrets Manager: secretsmanager (+ kms for decrypt)
  # - Common auth: sts
  interface_vpc_endpoints = toset([
    "ecr.api",
    "ecr.dkr",
    "logs",
    "secretsmanager",
    "kms",
    "sts",
  ])
}

resource "aws_vpc_endpoint" "interface_endpoints" {
  for_each = local.interface_vpc_endpoints

  vpc_id              = aws_vpc.vpc.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = [aws_subnet.app_subnet_az1.id, aws_subnet.app_subnet_az2.id]
  security_group_ids = [aws_security_group.sg_vpc_endpoints.id]

  tags = {
    Name    = "${var.project}-${var.env}-vpce-${each.value}"
    Env     = var.env
    Project = var.project
  }
}

# Gateway endpoint for S3 (used by ECR for image layers; also generally useful)
resource "aws_vpc_endpoint" "s3_gateway" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.app_rt_az1.id,
    aws_route_table.app_rt_az2.id,
  ]

  tags = {
    Name    = "${var.project}-${var.env}-vpce-s3"
    Env     = var.env
    Project = var.project
  }
}
