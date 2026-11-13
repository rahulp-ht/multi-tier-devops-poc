# Private subnet group for Amazon RDS
resource "aws_db_subnet_group" "mysql" {
  count = var.enable_rds ? 1 : 0

  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# Amazon RDS MySQL
resource "aws_db_instance" "mysql" {
  count = var.enable_rds ? 1 : 0

  identifier = "${var.project_name}-db"

  engine         = "mysql"
  engine_version = "8.0"

  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_type      = "gp3"

  db_name  = "react_node_app"
  username = "admin"

  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.mysql[0].name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible = false
  multi_az            = false

  backup_retention_period = 1
  storage_encrypted       = true

  deletion_protection = true
  skip_final_snapshot = false

  tags = {
    Name = "${var.project_name}-mysql"
  }
}
# Application database credentials
resource "aws_secretsmanager_secret" "app_db" {
  count = var.enable_rds ? 1 : 0

  name                    = "${var.project_name}/app-db"
  description             = "Database credentials for the POC application"
  recovery_window_in_days = 7

  tags = {
    Name = "${var.project_name}-app-db-secret"
  }
}
