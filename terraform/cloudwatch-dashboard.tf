
locals {
  monitoring_dashboard_name = "multi-tier-poc-monitoring"

  monitoring_region = "ap-south-1"

  monitoring_widgets = [
    {
      type   = "text"
      x      = 0
      y      = 0
      width  = 24
      height = 2

      properties = {
        markdown = "# Multi-Tier DevOps POC\nECS | EC2 | RDS | ALB"
      }
    },
    {
      type   = "metric"
      x      = 0
      y      = 2
      width  = 12
      height = 6

      properties = {
        title  = "ECS - CPU Utilization"
        region = local.monitoring_region
        stat   = "Average"
        period = 300
        metrics = [
          ["AWS/ECS", "CPUUtilization", "ClusterName", "multi-tier-poc-cluster", "ServiceName", "multi-tier-poc-frontend"],
          ["AWS/ECS", "CPUUtilization", "ClusterName", "multi-tier-poc-cluster", "ServiceName", "multi-tier-poc-backend"]
        ]
      }
    },
    {
      type   = "metric"
      x      = 12
      y      = 2
      width  = 12
      height = 6

      properties = {
        title  = "ECS - Memory Utilization"
        region = local.monitoring_region
        stat   = "Average"
        period = 300
        metrics = [
          ["AWS/ECS", "MemoryUtilization", "ClusterName", "multi-tier-poc-cluster", "ServiceName", "multi-tier-poc-frontend"],
          ["AWS/ECS", "MemoryUtilization", "ClusterName", "multi-tier-poc-cluster", "ServiceName", "multi-tier-poc-backend"]
        ]
      }
    },
    {
      type   = "metric"
      x      = 0
      y      = 8
      width  = 12
      height = 6

      properties = {
        title   = "EC2 - CPU Utilization"
        region  = local.monitoring_region
        stat    = "Average"
        period  = 300
        metrics = [
          ["AWS/EC2", "CPUUtilization", "InstanceId", var.monitoring_ec2_instance_id]
        ]
      }
    },
    {
      type   = "metric"
      x      = 12
      y      = 8
      width  = 12
      height = 6

      properties = {
        title  = "RDS - CPU and Connections"
        region = local.monitoring_region
        period = 300
        metrics = [
          ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", "multi-tier-poc-db", { stat = "Average", yAxis = "left" }],
          ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", "multi-tier-poc-db", { stat = "Average", yAxis = "right" }]
        ]
      }
    },
    {
      type   = "metric"
      x      = 0
      y      = 14
      width  = 12
      height = 6

      properties = {
        title  = "RDS - Free Storage Space"
        region = local.monitoring_region
        stat   = "Average"
        period = 300
        metrics = [
          ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", "multi-tier-poc-db"]
        ]
      }
    },
    {
      type   = "metric"
      x      = 12
      y      = 14
      width  = 12
      height = 6

      properties = {
        title  = "ALB - Requests and HTTP 5xx"
        region = local.monitoring_region
        period = 300
        metrics = [
          ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.monitoring_alb_suffix, { stat = "Sum", yAxis = "left" }],
          ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.monitoring_alb_suffix, { stat = "Sum", yAxis = "right" }],
          ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.monitoring_alb_suffix, { stat = "Sum", yAxis = "right" }]
        ]
      }
    },
    {
      type   = "metric"
      x      = 0
      y      = 20
      width  = 12
      height = 6

      properties = {
        title  = "ALB - Target Response Time"
        region = local.monitoring_region
        stat   = "Average"
        period = 300
        metrics = [
          ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.monitoring_alb_suffix]
        ]
      }
    }
  ]
}

variable "monitoring_ec2_instance_id" {
  description = "ECS container instance EC2 ID"
  type        = string
}

variable "monitoring_alb_suffix" {
  description = "ALB ARN suffix, e.g. app/name/id"
  type        = string
}

resource "aws_cloudwatch_dashboard" "poc" {
  dashboard_name = local.monitoring_dashboard_name
  dashboard_body = jsonencode({
    widgets = local.monitoring_widgets
  })
}

