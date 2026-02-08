# Data source to automatically fetch available AZs for the region
data "aws_availability_zones" "available" {
  state = "available"
}

# Local variables for easy reference to the first two AZs
locals {
  az1 = data.aws_availability_zones.available.names[0]
  az2 = data.aws_availability_zones.available.names[1]
}

# VPC for Two-Tier Application
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "${var.project}-${var.env}-vpc"
    Env     = var.env
    Project = var.project
  }
}

# Public Subnets for Two-Tier Application VPC
resource "aws_subnet" "public_subnet_az1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_subnet_cidrs[0]
  availability_zone       = local.az1
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project}-${var.env}-public_subnet_az1"
    Env     = var.env
    Project = var.project
  }
}

resource "aws_subnet" "public_subnet_az2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_subnet_cidrs[1]
  availability_zone       = local.az2
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project}-${var.env}-public_subnet_az2"
    Env     = var.env
    Project = var.project
  }
}

# Internet Gateway for VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name    = "${var.project}-${var.env}-igw"
    Env     = var.env
    Project = var.project
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name    = "${var.project}-${var.env}-public_rt"
    Env     = var.env
    Project = var.project
  }
}

resource "aws_route_table_association" "public_rt_assoc_az1" {
  subnet_id      = aws_subnet.public_subnet_az1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_rt_assoc_az2" {
  subnet_id      = aws_subnet.public_subnet_az2.id
  route_table_id = aws_route_table.public_rt.id
}

# Application Subnets for Two-Tier Application VPC
resource "aws_subnet" "app_subnet_az1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.app_subnet_cidrs[0]
  availability_zone = local.az1

  tags = {
    Name    = "${var.project}-${var.env}-app_subnet_az1"
    Env     = var.env
    Project = var.project
  }
}

resource "aws_subnet" "app_subnet_az2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.app_subnet_cidrs[1]
  availability_zone = local.az2

  tags = {
    Name    = "${var.project}-${var.env}-app_subnet_az2"
    Env     = var.env
    Project = var.project
  }
}

# Route Table for Application Subnets
resource "aws_route_table" "app_rt_az1" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name    = "${var.project}-${var.env}-app_rt_az1"
    Env     = var.env
    Project = var.project
  }
}

resource "aws_route_table_association" "app_rt_assoc_az1" {
  subnet_id      = aws_subnet.app_subnet_az1.id
  route_table_id = aws_route_table.app_rt_az1.id
}

resource "aws_route_table" "app_rt_az2" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name    = "${var.project}-${var.env}-app_rt_az2"
    Env     = var.env
    Project = var.project
  }
}

resource "aws_route_table_association" "app_rt_assoc_az2" {
  subnet_id      = aws_subnet.app_subnet_az2.id
  route_table_id = aws_route_table.app_rt_az2.id
}

# Database Subnets for Two-Tier Application VPC
resource "aws_subnet" "db_subnet_az1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.db_subnet_cidrs[0]
  availability_zone = local.az1

  tags = {
    Name    = "${var.project}-${var.env}-db_subnet_az1"
    Env     = var.env
    Project = var.project
  }
}

resource "aws_subnet" "db_subnet_az2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.db_subnet_cidrs[1]
  availability_zone = local.az2

  tags = {
    Name    = "${var.project}-${var.env}-db_subnet_az2"
    Env     = var.env
    Project = var.project
  }
}

# Route Table for DB Subnets
resource "aws_route_table" "db_rt" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name    = "${var.project}-${var.env}-db_rt"
    Env     = var.env
    Project = var.project
  }
}

resource "aws_route_table_association" "db_rt_assoc_az1" {
  subnet_id      = aws_subnet.db_subnet_az1.id
  route_table_id = aws_route_table.db_rt.id
}

resource "aws_route_table_association" "db_rt_assoc_az2" {
  subnet_id      = aws_subnet.db_subnet_az2.id
  route_table_id = aws_route_table.db_rt.id
}
