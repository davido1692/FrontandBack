variable "vpc_id" {
  type = string
}

variable "private_subnets" {
  type = list(string)
}

variable "cluster_id" {
  type = string
}

variable "task_execution_role_arn" {
  type = string
}


############################################
# EFS for Prometheus storage
############################################

resource "aws_security_group" "efs_sg" {
  name        = "prometheus-efs-sg"
  description = "Allow NFS access from Prometheus"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.prom_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_efs_file_system" "prometheus" {
  creation_token = "prometheus-efs"
}

resource "aws_efs_mount_target" "prometheus" {
  count          = length(var.private_subnets)
  file_system_id = aws_efs_file_system.prometheus.id
  subnet_id      = var.private_subnets[count.index]
  security_groups = [
    aws_security_group.efs_sg.id
  ]
}

############################################
# Prometheus Security Group
############################################

resource "aws_security_group" "prom_sg" {
  name        = "prometheus-sg"
  description = "Prometheus outbound + EFS access"
  vpc_id      = var.vpc_id

  # Outbound to AWS APIs (CloudWatch exporter)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############################################
# Task Definition
############################################

data "aws_region" "current" {}

resource "aws_ecs_task_definition" "prometheus" {
  family                   = "prometheus"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"

  execution_role_arn = var.task_execution_role_arn
  task_role_arn      = var.task_execution_role_arn

  container_definitions = jsonencode([
    {
      name  = "prometheus"
      image = "prom/prometheus:latest"
      essential = true
      portMappings = [
        {
          containerPort = 9090
          hostPort      = 9090
        }
      ]
      command = [
        "--config.file=/etc/prometheus/prometheus.yml",
        "--storage.tsdb.path=/prometheus",
        "--storage.tsdb.retention.time=14d"
      ]
      mountPoints = [
        {
          sourceVolume  = "prometheus_data"
          containerPath = "/prometheus"
        }
      ]
    },
    {
      name  = "cloudwatch-exporter"
      image = "prom/cloudwatch-exporter:latest"
      essential = true
      portMappings = [
        {
          containerPort = 9106
          hostPort      = 9106
        }
      ]
      environment = [
        {
          name  = "AWS_REGION"
          value = data.aws_region.current.name
        }
      ]
    }
  ])

  volume {
    name = "prometheus_data"

    efs_volume_configuration {
      file_system_id = aws_efs_file_system.prometheus.id
      root_directory = "/"
    }
  }
}

############################################
# ECS Service
############################################

resource "aws_ecs_service" "prometheus" {
  name            = "prometheus"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.prometheus.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.private_subnets
    security_groups = [aws_security_group.prom_sg.id]
  }

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100
}

############################################
# Prometheus Config File (local)
############################################

locals {
  prometheus_config = <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'cloudwatch'
    static_configs:
      - targets: ['localhost:9106']

  - job_name: 'ecs-task-metadata'
    metrics_path: /metrics
    static_configs:
      - targets: ['169.254.170.2:51678']
EOF
}
