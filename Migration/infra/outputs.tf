output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "frontend_url" {
  description = "URL to access the frontend"
  value       = "http://${aws_lb.main.dns_name}"
}

output "backend_url" {
  description = "URL to access the backend API"
  value       = "http://${aws_lb.main.dns_name}:8080"
}

output "ecr_backend_url" {
  description = "ECR repository URL for backend images"
  value       = aws_ecr_repository.backend.repository_url
}

output "ecr_frontend_url" {
  description = "ECR repository URL for frontend images"
  value       = aws_ecr_repository.frontend.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "backend_service_name" {
  description = "ECS backend service name"
  value       = aws_ecs_service.backend.name
}

output "frontend_service_name" {
  description = "ECS frontend service name"
  value       = aws_ecs_service.frontend.name
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions OIDC - use as AWS_ROLE_ARN secret"
  value       = aws_iam_role.github_actions.arn
}
