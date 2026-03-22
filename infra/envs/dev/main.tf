module "vpc" {
  source               = "../../modules/vpc"
  vpc_cidr             = "10.0.0.0/16"
  azs                  = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs  = ["10.0.0.0/20", "10.0.16.0/20"]
  private_subnet_cidrs = ["10.0.32.0/20", "10.0.48.0/20"]
}

module "frontend_ecr" {
  source = "../../modules/ecr"
  name   = "frontend"
}

module "backend_ecr" {
  source = "../../modules/ecr"
  name   = "backend"
}

module "alb" {
  source             = "../../modules/alb"
  vpc_id             = module.vpc.vpc_id
  public_subnets     = module.vpc.public_subnets
  security_group_ids = [aws_security_group.alb_sg.id]
}

module "ecs_cluster" {
  source       = "../../modules/ecs-cluster"
  cluster_name = "dev-cluster"
}

module "frontend_blue" {
  source                  = "../../modules/ecs-service"
  cluster_id              = module.ecs_cluster.cluster_id
  service_name            = "frontend-blue"
  container_image         = "751545121618.dkr.ecr.us-east-1.amazonaws.com/frontend:v1"
  container_port          = 3000
  private_subnets         = module.vpc.private_subnets
  task_execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  target_group_arn        = module.alb.blue_tg_arn
  security_group_ids      = [aws_security_group.ecs_sg.id]
  listener_arn            = module.alb.listener_arn
}

module "frontend_green" {
  source                  = "../../modules/ecs-service"
  cluster_id              = module.ecs_cluster.cluster_id
  service_name            = "frontend-green"
  container_image         = "751545121618.dkr.ecr.us-east-1.amazonaws.com/frontend:v1"
  container_port          = 3000
  private_subnets         = module.vpc.private_subnets
  task_execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  security_group_ids      = [aws_security_group.ecs_sg.id]
}

module "backend_blue" {
  source                  = "../../modules/ecs-service"
  cluster_id              = module.ecs_cluster.cluster_id
  service_name            = "backend-blue"
  container_image         = "751545121618.dkr.ecr.us-east-1.amazonaws.com/backend:v1"
  container_port          = 8080
  private_subnets         = module.vpc.private_subnets
  task_execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
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
  source                  = "../../modules/ecs-service"
  cluster_id              = module.ecs_cluster.cluster_id
  service_name            = "backend-green"
  container_image         = "751545121618.dkr.ecr.us-east-1.amazonaws.com/backend:v1"
  container_port          = 8080
  private_subnets         = module.vpc.private_subnets
  task_execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  security_group_ids      = [aws_security_group.ecs_sg.id]
  environment = [
    {
      name  = "CORS_ORIGIN"
      value = "http://${module.alb.alb_dns}"
    }
  ]
}

resource "aws_security_group" "alb_sg" {
  name   = "dev-alb-sg"
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
  name   = "dev-ecs-sg"
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

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_cloudwatch_log_group" "frontend_blue" {
  name              = "/ecs/frontend-blue"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "frontend_green" {
  name              = "/ecs/frontend-green"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "backend_blue" {
  name              = "/ecs/backend-blue"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "backend_green" {
  name              = "/ecs/backend-green"
  retention_in_days = 7
}
