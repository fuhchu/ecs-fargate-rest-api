# Outputs expose key resource IDs so later milestones (ALB, ECS) — and you, on
# the CLI — can reference them without digging through the AWS console.

output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (the ALB will live here)."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (the Fargate tasks will live here)."
  value       = aws_subnet.private[*].id
}

output "ecr_repository_url" {
  description = "Registry URL used to docker tag/push/pull the app image."
  value       = aws_ecr_repository.app.repository_url
}

output "alb_dns_name" {
  description = "Public DNS name of the load balancer — this is your app's URL."
  value       = aws_lb.main.dns_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name (handy for CLI debugging)."
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service name (handy for CLI debugging)."
  value       = aws_ecs_service.app.name
}

output "github_actions_role_arn" {
  description = "ARN of the IAM role GitHub Actions assumes via OIDC (used in the workflow)."
  value       = aws_iam_role.github_actions.arn
}
