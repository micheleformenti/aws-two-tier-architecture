# Generate a random database password
resource "random_password" "db_password" {
  length  = 32
  special = false
}

# Store database password in AWS Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.project}-${var.env}-rds-password"
  recovery_window_in_days = var.secrets_recovery_window_days

  tags = {
    Name    = "${var.project}-${var.env}-rds-password"
    Env     = var.env
    Project = var.project
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result
}

# Generate a random Flask secret key
resource "random_password" "flask_secret_key" {
  length  = 32
  special = true
}

# Store Flask secret key in AWS Secrets Manager (random value)
resource "aws_secretsmanager_secret" "flask_secret_key" {
  name                    = "${var.project}-${var.env}-flaskapp-secret-key"
  recovery_window_in_days = var.secrets_recovery_window_days

  tags = {
    Name    = "${var.project}-${var.env}-flaskapp-secret-key"
    Env     = var.env
    Project = var.project
  }
}

resource "aws_secretsmanager_secret_version" "flask_secret_key" {
  secret_id     = aws_secretsmanager_secret.flask_secret_key.id
  secret_string = random_password.flask_secret_key.result
}
