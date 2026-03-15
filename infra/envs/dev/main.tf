module "vpc" {
  source = "../../modules/vpc"
  vpc_cidr = "10.0.0.0/16"
  azs = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs  = ["10.0.0.0/20", "10.0.16.0/20"]
  private_subnet_cidrs = ["10.0.32.0/20", "10.0.48.0/20"]
}

module "frontend_ecr" {
  source = "../../modules/ecr"
  name   = "frontend"
}

module "alb" {
  source = "../../modules/alb"
  vpc_id = module.vpc.vpc_id
  public_subnets = module.vpc.public_subnets
  security_group_ids = [aws_security_group.alb_sg.id]
}

module "ecs_cluster" {
  source = "../../modules/ecs-cluster"
  cluster_name = "dev-cluster"
}

module "frontend_blue" {
  source = "../../modules/ecs-service"
  cluster_id = module.ecs_cluster.cluster_id
  service_name = "frontend-blue"
  container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/frontend:latest"
  private_subnets = module.vpc.private_subnets
  task_execution_role_arn = module.ecs_cluster.task_execution_role_arn
  target_group_arn = module.alb.blue_tg_arn
  security_group_ids = [aws_security_group.ecs_sg.id]
}

module "frontend_green" {
  source = "../../modules/ecs-service"
  cluster_id = module.ecs_cluster.cluster_id
  service_name = "frontend-green"
  container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/frontend:latest"
  private_subnets = module.vpc.private_subnets
  task_execution_role_arn = module.ecs_cluster.task_execution_role_arn
  target_group_arn = module.alb.green_tg_arn
  security_group_ids = [aws_security_group.ecs_sg.id]
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
