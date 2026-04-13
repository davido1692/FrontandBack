variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "migration-app"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "backend_image" {
  description = "Backend ECR image URI (set by CI/CD pipeline)"
  type        = string
  default     = "nginx:alpine"
}

variable "frontend_image" {
  description = "Frontend ECR image URI (set by CI/CD pipeline)"
  type        = string
  default     = "nginx:alpine"
}

variable "github_org" {
  description = "GitHub username or organization for OIDC trust"
  type        = string
  default     = "davido1692"
}

variable "github_repo" {
  description = "GitHub repository name for OIDC trust"
  type        = string
  default     = "FrontandBack"
}
