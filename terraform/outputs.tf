output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "internet_gateway_id" {
  value = aws_internet_gateway.main.id
}
output "ecr_repository_urls" {
  description = "ECR repository URLs for Jenkins and ECS"

  value = {
    for name, repo in aws_ecr_repository.app :
    name => repo.repository_url
  }
}

output "ecr_repository_arns" {
  description = "ECR repository ARNs"

  value = {
    for name, repo in aws_ecr_repository.app :
    name => repo.arn
  }
}
