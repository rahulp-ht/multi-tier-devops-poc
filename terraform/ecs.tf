# Latest ECS-optimized Amazon Linux 2023 AMI
data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}

# ECS cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = {
    Name = "${var.project_name}-cluster"
  }
}

# Security group for EC2 container hosts
resource "aws_security_group" "ecs_instance" {
  name        = "${var.project_name}-ecs-instance-sg"
  description = "Security group for private ECS EC2 instances"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-ecs-instance-sg"
  }
}

# EC2 Launch Template
resource "aws_launch_template" "ecs" {
  count = var.enable_ecs_capacity ? 1 : 0

  name_prefix   = "${var.project_name}-ecs-"
  image_id      = data.aws_ssm_parameter.ecs_ami.value
  instance_type = "c7i-flex.large"

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance.name
  }

  vpc_security_group_ids = [
    aws_security_group.ecs_instance.id
  ]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
  EOF
  )

  metadata_options {
    http_tokens = "required"
  }

  monitoring {
    enabled = false
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.project_name}-ecs-instance"
    }
  }
}

# EC2 Auto Scaling Group
resource "aws_autoscaling_group" "ecs" {
  count = var.enable_ecs_capacity ? 1 : 0

  name             = "${var.project_name}-ecs-asg"
  min_size         = 2
  max_size         = 4
  desired_capacity = 2
  # Cost-optimized POC: launch ECS hosts in endpoint AZ
  vpc_zone_identifier = aws_subnet.private[*].id
  launch_template {
    id      = aws_launch_template.ecs[0].id
    version = "$Latest"
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = ""
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-ecs-instance"
    propagate_at_launch = true
  }
}

# ECS Capacity Provider
resource "aws_ecs_capacity_provider" "ec2" {
  count = var.enable_ecs_capacity ? 1 : 0

  name = "${var.project_name}-ec2-capacity"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs[0].arn

    managed_scaling {
      status          = "ENABLED"
      target_capacity = 100
    }

    managed_termination_protection = "DISABLED"
  }
}

# Associate capacity provider with ECS cluster
resource "aws_ecs_cluster_capacity_providers" "main" {
  count = var.enable_ecs_capacity ? 1 : 0

  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = [aws_ecs_capacity_provider.ec2[0].name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ec2[0].name
    weight            = 1
  }
}
