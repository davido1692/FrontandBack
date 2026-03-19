############################################
# PROD VPC
############################################
module "vpc" {
  source = "../../modules/vpc"

  vpc_cidr             = "10.1.0.0/16"
  azs                  = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs  = ["10.1.0.0/20", "10.1.16.0/20"]
  private_subnet_cidrs = ["10.1.32.0/20", "10.1.48.0/20"]
}

############################################
# PROD ECR
############################################
module "frontend_ecr" {
  source = "../../modules/ecr"
  name   = "frontend-prod"
}

module "backend_ecr" {
  source = "../../modules/ecr"
  name   = "backend-prod"
}

############################################
# PROD SECURITY GROUPS
############################################
resource "aws_security_group" "alb_sg" {
  name   = "prod-alb-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs_sg" {
  name   = "prod-ecs-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############################################
# PROD ALB
############################################
module "alb" {
  source = "../../modules/alb"

  vpc_id             = module.vpc.vpc_id
  public_subnets     = module.vpc.public_subnets
  security_group_ids = [aws_security_group.alb_sg.id]
}

############################################
# PROD ECS CLUSTER
############################################
module "ecs_cluster" {
  source       = "../../modules/ecs-cluster"
  cluster_name = "prod-cluster"
}

############################################
# PROD FRONTEND SERVICES
############################################
module "frontend_blue" {
  source = "../../modules/ecs-service"

  cluster_id              = module.ecs_cluster.cluster_id
  service_name            = "frontend-blue-prod"
  container_image         = "${module.frontend_ecr.repository_url}:stable"
  container_port          = 3000
  private_subnets         = module.vpc.private_subnets
  task_execution_role_arn = module.ecs_cluster.task_execution_role_arn
  target_group_arn        = module.alb.blue_tg_arn
  security_group_ids      = [aws_security_group.ecs_sg.id]
  listener_arn            = module.alb.listener_arn
}

module "frontend_green" {
  source = "../../modules/ecs-service"

  cluster_id              = module.ecs_cluster.cluster_id
  service_name            = "frontend-green-prod"
  container_image         = "${module.frontend_ecr.repository_url}:stable"
  container_port          = 3000
  private_subnets         = module.vpc.private_subnets
  task_execution_role_arn = module.ecs_cluster.task_execution_role_arn
  target_group_arn        = module.alb.green_tg_arn
  security_group_ids      = [aws_security_group.ecs_sg.id]
  listener_arn            = module.alb.listener_arn
}

############################################
# PROD BACKEND SERVICES
############################################
module "backend_blue" {
  source = "../../modules/ecs-service"

  cluster_id              = module.ecs_cluster.cluster_id
  service_name            = "backend-blue-prod"
  container_image         = "${module.backend_ecr.repository_url}:stable"
  container_port          = 8080
  private_subnets         = module.vpc.private_subnets
  task_execution_role_arn = module.ecs_cluster.task_execution_role_arn
  target_group_arn        = module.alb.backend_blue_tg_arn
  security_group_ids      = [aws_security_group.ecs_sg.id]
  listener_arn            = module.alb.listener_arn
  environment = [
    {
      name  = "CORS_ORIGIN"
      value = "http://${module.alb.alb_dns}"
    }
  ]
}

module "backend_green" {
  source = "../../modules/ecs-service"

  cluster_id              = module.ecs_cluster.cluster_id
  service_name            = "backend-green-prod"
  container_image         = "${module.backend_ecr.repository_url}:stable"
  container_port          = 8080
  private_subnets         = module.vpc.private_subnets
  task_execution_role_arn = module.ecs_cluster.task_execution_role_arn
  target_group_arn        = module.alb.backend_green_tg_arn
  security_group_ids      = [aws_security_group.ecs_sg.id]
  listener_arn            = module.alb.listener_arn
  environment = [
    {
      name  = "CORS_ORIGIN"
      value = "http://${module.alb.alb_dns}"
    }
  ]
}

############################################
# PROD CLOUDWATCH LOG GROUPS
############################################
resource "aws_cloudwatch_log_group" "frontend_blue" {
  name              = "/ecs/frontend-blue-prod"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "frontend_green" {
  name              = "/ecs/frontend-green-prod"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "backend_blue" {
  name              = "/ecs/backend-blue-prod"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "backend_green" {
  name              = "/ecs/backend-green-prod"
  retention_in_days = 30
}

############################################
# MONITORING
############################################
module "prometheus" {
  source                  = "../../modules/prometheus"
  cluster_id              = module.ecs_cluster.cluster_id
  private_subnets         = module.vpc.private_subnets
  vpc_id                  = module.vpc.vpc_id
  task_execution_role_arn = module.ecs_cluster.task_execution_role_arn
}

module "grafana" {
  source                  = "../../modules/grafana"
  cluster_id              = module.ecs_cluster.cluster_id
  private_subnets         = module.vpc.private_subnets
  vpc_id                  = module.vpc.vpc_id
  task_execution_role_arn = module.ecs_cluster.task_execution_role_arn
  prometheus_internal_url = "http://localhost:9090"
}
