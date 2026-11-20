# ALB Security Group
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for public ALB"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# ECS Frontend Security Group
resource "aws_security_group" "ecs_frontend" {
  name        = "${var.project_name}-frontend-sg"
  description = "Security group for frontend ECS tasks"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-frontend-sg"
  }
}

# ECS Backend Security Group
resource "aws_security_group" "ecs_backend" {
  name        = "${var.project_name}-backend-sg"
  description = "Security group for backend ECS tasks"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-backend-sg"
  }
}

# RDS Security Group
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Allow MySQL only from ECS backend"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# Internet to ALB
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "HTTP from internet"
}

# ALB to Frontend
resource "aws_vpc_security_group_ingress_rule" "frontend_http" {
  security_group_id            = aws_security_group.ecs_frontend.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "HTTP from ALB"
}

# ALB to Backend
resource "aws_vpc_security_group_ingress_rule" "backend_api" {
  security_group_id            = aws_security_group.ecs_backend.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 3200
  to_port                      = 3200
  ip_protocol                  = "tcp"
  description                  = "API traffic from ALB"
}

# Backend to RDS
resource "aws_vpc_security_group_ingress_rule" "rds_mysql" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.ecs_backend.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  description                  = "MySQL from backend ECS tasks"
}

# ALB outbound to application tasks
resource "aws_vpc_security_group_egress_rule" "alb_to_frontend" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.ecs_frontend.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_backend" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.ecs_backend.id
  from_port                    = 3200
  to_port                      = 3200
  ip_protocol                  = "tcp"
}

# Frontend outbound: DNS and backend communication
# Additional rules will be defined once application routing is finalized.

# Backend outbound to MySQL
resource "aws_vpc_security_group_egress_rule" "backend_to_rds" {
  security_group_id            = aws_security_group.ecs_backend.id
  referenced_security_group_id = aws_security_group.rds.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}
# ECS EC2 instances -> AWS service endpoints
# Public AWS service IPs can change. NAT egress is limited to outbound TCP 443.
# trivy:ignore:AWS-0104
resource "aws_vpc_security_group_egress_rule" "ecs_instance_https" {
  security_group_id = aws_security_group.ecs_instance.id
  description       = "HTTPS to AWS service endpoints"

  cidr_ipv4   = var.enable_ecs_public_https_egress ? "0.0.0.0/0" : var.vpc_cidr
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
}

# ECS EC2 instances -> S3 Gateway endpoint
resource "aws_vpc_security_group_egress_rule" "ecs_instance_s3" {
  security_group_id = aws_security_group.ecs_instance.id
  description       = "HTTPS to S3 for ECR image layers"

  prefix_list_id = data.aws_prefix_list.s3.id
  from_port      = 443
  to_port        = 443
  ip_protocol    = "tcp"
}

# Frontend task -> AWS service endpoints
# Public AWS service IPs can change. NAT egress is limited to outbound TCP 443.
# trivy:ignore:AWS-0104
resource "aws_vpc_security_group_egress_rule" "frontend_https" {
  security_group_id = aws_security_group.ecs_frontend.id
  description       = "HTTPS to AWS service endpoints"

  cidr_ipv4   = var.enable_ecs_public_https_egress ? "0.0.0.0/0" : var.vpc_cidr
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
}

# Backend task -> AWS service endpoints
# Public AWS service IPs can change. NAT egress is limited to outbound TCP 443.
# trivy:ignore:AWS-0104
resource "aws_vpc_security_group_egress_rule" "backend_https" {
  security_group_id = aws_security_group.ecs_backend.id
  description       = "HTTPS to AWS service endpoints"

  cidr_ipv4   = var.enable_ecs_public_https_egress ? "0.0.0.0/0" : var.vpc_cidr
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
}
# Allow ECS EC2 host to initialize the private RDS database.
# Remove this rule after database initialization.
resource "aws_vpc_security_group_ingress_rule" "rds_from_ecs_instance" {
  count = var.enable_rds && var.enable_ecs_capacity ? 1 : 0

  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.ecs_instance.id

  from_port   = 3306
  to_port     = 3306
  ip_protocol = "tcp"

  description = "Temporary MySQL access for database initialization"
}
# Temporary outbound MySQL access for database initialization.
# Remove after database initialization.
resource "aws_vpc_security_group_egress_rule" "ecs_instance_to_rds" {
  count = var.enable_rds && var.enable_ecs_capacity ? 1 : 0

  security_group_id            = aws_security_group.ecs_instance.id
  referenced_security_group_id = aws_security_group.rds.id

  from_port   = 3306
  to_port     = 3306
  ip_protocol = "tcp"

  description = "Temporary MySQL access for RDS initialization"
}
