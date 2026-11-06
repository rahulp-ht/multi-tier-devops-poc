variable "aws_region" {

  description = "AWS deployment region"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name for resource tagging"
  type        = string
  default     = "multi-tier-poc"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_vpc_endpoints" {
  description = "Enable billable VPC endpoints for private ECS connectivity"
  type        = bool
  default     = false
}
variable "enable_rds" {
  description = "Enable billable Amazon RDS MySQL resources"
  type        = bool
  default     = false
}
variable "enable_ecs_capacity" {
  description = "Enable billable ECS EC2 capacity"
  type        = bool
  default     = false
}
variable "enable_alb" {
  description = "Enable billable Application Load Balancer"
  type        = bool
  default     = false
}
variable "enable_ecs_tasks" {
  description = "Register ECS task definitions after infrastructure is ready"
  type        = bool
  default     = false
}
variable "enable_ecs_services" {
  description = "Enable ECS frontend and backend services"
  type        = bool
  default     = false

  validation {
    condition = !var.enable_ecs_services || (
      var.enable_ecs_tasks &&
      var.enable_ecs_capacity &&
      var.enable_alb &&
      var.enable_rds &&
      var.enable_vpc_endpoints
    )
    error_message = "ECS services require tasks, EC2 capacity, ALB, RDS and VPC endpoints."
  }
}
