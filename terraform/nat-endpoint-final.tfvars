enable_s3_gateway_endpoint     = true
enable_ecs_public_https_egress = true

excluded_interface_endpoints = [
  "ec2messages",
  "ecr.api",
  "ecr.dkr",
  "ecs",
  "ecs-agent",
  "ecs-telemetry",
  "logs",
  "secretsmanager",
  "ssm",
  "ssmmessages",
]
