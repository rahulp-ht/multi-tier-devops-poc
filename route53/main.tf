terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Reuse the existing public hosted zone. This does not create a new zone.
data "aws_route53_zone" "domain" {
  name         = "therahulpatil.in."
  private_zone = false
}

# Look up the existing POC Application Load Balancer by name.
data "aws_lb" "poc" {
  name = var.alb_name
}

resource "aws_route53_record" "poc" {
  zone_id = data.aws_route53_zone.domain.zone_id
  name    = "poc.therahulpatil.in"
  type    = "A"

  alias {
    name                   = data.aws_lb.poc.dns_name
    zone_id                = data.aws_lb.poc.zone_id
    evaluate_target_health = true
  }
}

output "poc_domain" {
  value = aws_route53_record.poc.fqdn
}

output "alb_dns_name" {
  value = data.aws_lb.poc.dns_name
}
