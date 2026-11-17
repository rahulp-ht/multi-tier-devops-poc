locals {
  interface_endpoint_services = toset([
    "ecr.api",
    "ecr.dkr",
    "logs",
    "ecs",
    "ecs-agent",
    "ecs-telemetry",
    "secretsmanager",
    "ssm",
    "ssmmessages",
    "ec2messages"
  ])
}

# Security group for interface VPC endpoints
resource "aws_security_group" "vpc_endpoints" {
  count = var.enable_vpc_endpoints ? 1 : 0

  name_prefix = "${var.project_name}-vpce-"
  description = "HTTPS access to private AWS service endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS from private ECS subnets"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = aws_subnet.private[*].cidr_block
  }

  tags = {
    Name = "${var.project_name}-vpce-sg"
  }
}

# Private interface endpoints
resource "aws_vpc_endpoint" "interface" {
  for_each = var.enable_vpc_endpoints ? local.interface_endpoint_services : toset([])

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  # Cost optimization: one endpoint ENI per service in AZ A
  # Deploy endpoint interfaces in both Availability Zones
  subnet_ids = [
    aws_subnet.private[0].id, # ap-south-1a
    aws_subnet.private[1].id  # ap-south-1b
  ]
  security_group_ids = [
    aws_security_group.vpc_endpoints[0].id
  ]

  tags = {
    Name = "${var.project_name}-${replace(each.key, ".", "-")}-vpce"
  }
}

# S3 Gateway endpoint for ECR image layers
resource "aws_vpc_endpoint" "s3" {
  count = var.enable_vpc_endpoints ? 1 : 0

  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.private.id
  ]

  tags = {
    Name = "${var.project_name}-s3-vpce"
  }
}
data "aws_prefix_list" "s3" {
  name = "com.amazonaws.${var.aws_region}.s3"
}
