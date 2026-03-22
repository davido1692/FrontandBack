 resource "aws_iam_role" "codedeploy" {
    name = "codedeploy-role"

    assume_role_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect    = "Allow"
        Principal = { Service = "codedeploy.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }]
    })
  }

  resource "aws_iam_role_policy_attachment" "codedeploy" {
    role       = aws_iam_role.codedeploy.name
    policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
  }

    resource "aws_codedeploy_app" "app" {
    name             = "dev-app"
    compute_platform = "ECS"
  }

 resource "aws_codedeploy_deployment_group" "frontend" {
    app_name               = aws_codedeploy_app.app.name
    deployment_group_name  = "frontend-deployment-group"
    service_role_arn       = aws_iam_role.codedeploy.arn
    deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"

    auto_rollback_configuration {
      enabled = true
      events  = ["DEPLOYMENT_FAILURE"]
    }

    blue_green_deployment_config {
      deployment_ready_option {
        action_on_timeout = "CONTINUE_DEPLOYMENT"
      }
      terminate_blue_instances_on_deployment_success {
        action                           = "TERMINATE"
        termination_wait_time_in_minutes = 5
      }
    }

    deployment_style {
      deployment_option = "WITH_TRAFFIC_CONTROL"
      deployment_type   = "BLUE_GREEN"
    }

    ecs_service {
      cluster_name = module.ecs_cluster.cluster_name
      service_name = module.frontend_green.service_name
    }

    load_balancer_info {
      target_group_pair_info {
        prod_traffic_route {
          listener_arns = [module.alb.listener_arn]
        }
        target_group {
          name = "frontend-blue-tg"
        }
        target_group {
          name = "frontend-green-tg"
        }
      }
    }
  }

  resource "aws_codedeploy_deployment_group" "backend" {
    app_name               = aws_codedeploy_app.app.name
    deployment_group_name  = "backend-deployment-group"
    service_role_arn       = aws_iam_role.codedeploy.arn
    deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"

    auto_rollback_configuration {
      enabled = true
      events  = ["DEPLOYMENT_FAILURE"]
    }

    blue_green_deployment_config {
      deployment_ready_option {
        action_on_timeout = "CONTINUE_DEPLOYMENT"
      }
      terminate_blue_instances_on_deployment_success {
        action                           = "TERMINATE"
        termination_wait_time_in_minutes = 5
      }
    }

    deployment_style {
      deployment_option = "WITH_TRAFFIC_CONTROL"
      deployment_type   = "BLUE_GREEN"
    }

    ecs_service {
      cluster_name = module.ecs_cluster.cluster_name
      service_name = module.backend_green.service_name
    }

    load_balancer_info {
      target_group_pair_info {
        prod_traffic_route {
          listener_arns = [module.alb.listener_arn]
        }
        target_group {
          name = "backend-blue-tg"
        }
        target_group {
          name = "backend-green-tg"
        }
      }
    }
  }