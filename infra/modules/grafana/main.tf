############################################
# Variables
############################################

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

variable "prometheus_internal_url" {
  type = string
}

############################################
# Security Group
############################################

resource "aws_security_group" "grafana_sg" {
  name        = "grafana-sg"
  description = "Grafana private access only"
  vpc_id      = var.vpc_id

  # Outbound allowed (Grafana → Prometheus)
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

resource "aws_ecs_task_definition" "grafana" {
  family                   = "grafana"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"

  execution_role_arn = var.task_execution_role_arn
  task_role_arn      = var.task_execution_role_arn

  container_definitions = jsonencode([
    {
      name  = "grafana"
      image = "grafana/grafana:latest"
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
        }
      ]
      environment = [
        {
          name  = "GF_SECURITY_ADMIN_USER"
          value = "admin"
        },
        {
          name  = "GF_SECURITY_ADMIN_PASSWORD"
          value = "admin123"
        }
      ]
      volumeMounts = [
        {
          name      = "grafana-provisioning"
          mountPath = "/etc/grafana/provisioning/datasources"
          readOnly  = false
        }
      ]
    }
  ])

  volume {
    name = "grafana-provisioning"

    docker_volume_configuration {
      scope         = "task"
      autoprovision = true
    }
  }
}

############################################
# ECS Service
############################################

resource "aws_ecs_service" "grafana" {
  name            = "grafana"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.grafana.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.private_subnets
    security_groups = [aws_security_group.grafana_sg.id]
  }

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100
}

############################################
# Local Datasource File (Provisioning)
############################################

locals {
  grafana_datasource = <<EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: "${var.prometheus_internal_url}"
    isDefault: true
EOF
}
