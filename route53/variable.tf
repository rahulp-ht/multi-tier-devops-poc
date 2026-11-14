variable "aws_region" {
  description = "AWS region hosting the existing POC ALB"
  type        = string
  default     = "ap-south-1"
}

variable "alb_name" {
  description = "Name of the existing POC Application Load Balancer"
  type        = string
  default     = "multi-tier-poc-alb"
}
