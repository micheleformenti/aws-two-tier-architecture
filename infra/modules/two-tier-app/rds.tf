resource "aws_db_instance" "rds" {
  identifier        = "${var.project}-${var.env}-rds"
  instance_class    = var.rds_instance_class
  allocated_storage = var.rds_allocated_storage
  engine            = "postgres"
  engine_version    = "18.1"
  username          = "postgres"
  db_name           = var.db_name
  password          = aws_secretsmanager_secret_version.db_password.secret_string

  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.sg_rds.id]
  publicly_accessible    = false

  storage_encrypted = true
  multi_az          = true

  backup_retention_period = var.db_backup_retention_days
  deletion_protection     = false
  skip_final_snapshot     = true

  tags = {
    Name    = "${var.project}-${var.env}-rds"
    Env     = var.env
    Project = var.project
  }
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.project}-${var.env}-rds-subnet-group"
  subnet_ids = [aws_subnet.db_subnet_az1.id, aws_subnet.db_subnet_az2.id]

  tags = {
    Name    = "${var.project}-${var.env}-rds_subnet_group"
    Env     = var.env
    Project = var.project
  }
}
