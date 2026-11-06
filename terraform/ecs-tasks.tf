locals {
  ecs_tasks_enabled = (
    var.enable_ecs_tasks &&
    var.enable_rds &&
    var.enable_ecs_capacity
  )
}

resource "aws_cloudwatch_log_group" "ecs" {
  for_each = local.ecs_tasks_enabled ? toset(["frontend", "backend"]) : toset([])

  name              = "/ecs/${var.project_name}/${each.key}"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-${each.key}-logs"
  }
}

resource "aws_ecs_task_definition" "frontend" {
  count = local.ecs_tasks_enabled ? 1 : 0

  family                   = "${var.project_name}-frontend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]

  execution_role_arn = aws_iam_role.ecs_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "frontend"
      image     = "${aws_ecr_repository.app["frontend"].repository_url}:v1"
      essential = true

      cpu               = 256
      memoryReservation = 256

      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs["frontend"].name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "backend" {
  count = local.ecs_tasks_enabled ? 1 : 0

  family                   = "${var.project_name}-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]

  execution_role_arn = aws_iam_role.ecs_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = "${aws_ecr_repository.app["backend"].repository_url}:v1"
      essential = true

      cpu               = 512
      memoryReservation = 512

      portMappings = [
        {
          containerPort = 3200
          hostPort      = 3200
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "PORT"
          value = "3200"
        },
        {
          name  = "DB_HOST"
          value = aws_db_instance.mysql[0].address
        },
        {
          name  = "DB_PORT"
          value = "3306"
        },
        {
          name  = "DB_USER"
          value = "admin"
        },
        {
          name  = "DB_NAME"
          value = "react_node_app"
        }
      ]

      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = "${aws_db_instance.mysql[0].master_user_secret[0].secret_arn}:password::"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs["backend"].name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}
