# Add this file to the EXISTING route53/ Terraform root.
# Do not replace main.tf or move Terraform state.

data "aws_lb_target_group" "frontend" {
  name = "multi-tier-poc-frontend"
}

data "aws_lb_target_group" "backend" {
  name = "multi-tier-poc-backend"
}

resource "aws_acm_certificate" "poc" {
  domain_name       = "poc.therahulpatil.in"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "poc_certificate_validation" {
  for_each = {
    for dvo in aws_acm_certificate.poc.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id         = data.aws_route53_zone.domain.zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.record]
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "poc" {
  certificate_arn = aws_acm_certificate.poc.arn
  validation_record_fqdns = [
    for record in aws_route53_record.poc_certificate_validation : record.fqdn
  ]
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = data.aws_lb.poc.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.poc.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = data.aws_lb_target_group.frontend.arn
  }
}

resource "aws_lb_listener_rule" "https_api" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = data.aws_lb_target_group.backend.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

# IMPORTANT: Verify ALB security-group ingress before applying.
# This rule assumes the ALB has a single security group and no existing 443 rule.
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = one(data.aws_lb.poc.security_groups)
  description       = "Allow public HTTPS to POC ALB"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

output "poc_https_url" {
  value = "https://poc.therahulpatil.in"
}
