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
variable "enable_s3_gateway_endpoint" {
  description = "Enable the S3 gateway endpoint independently of interface endpoints"
  type        = bool
  default     = null
}

variable "interface_endpoints_without_private_dns" {
  description = "Interface endpoint services whose private DNS is disabled for cutover testing"
  type        = set(string)
  default     = []
}

variable "excluded_interface_endpoints" {
  description = "Interface endpoint services to remove after cutover testing"
  type        = set(string)
  default     = []
}

variable "enable_ecs_public_https_egress" {
  description = "Allow ECS hosts and tasks to reach public HTTPS endpoints through NAT"
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
      (var.enable_vpc_endpoints || var.enable_ecs_public_https_egress)
    )
    error_message = "ECS services require tasks, EC2 capacity, ALB, RDS and either VPC endpoints or public HTTPS egress."
  }
}
variable "ecs_image_tag" {
  description = "Git commit SHA used for frontend and backend ECS images"
  type        = string
}
