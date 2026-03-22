resource "aws_lb" "app" {
  name               = "app-alb"
  load_balancer_type = "application"
  subnets            = var.public_subnets
  security_groups    = var.security_group_ids
}

resource "aws_lb_target_group" "frontend_blue" {
  name        = "frontend-blue-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path = "/health"
  }
}

resource "aws_lb_target_group" "frontend_green" {
  name        = "frontend-green-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path = "/health"
  }
}

resource "aws_lb_target_group" "backend_blue" {
  name        = "backend-blue-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path = "/health"
  }
}

resource "aws_lb_target_group" "backend_green" {
  name        = "backend-green-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path = "/health"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_blue.arn
  }

  depends_on = [
    aws_lb_target_group.frontend_blue,
    aws_lb_target_group.frontend_green,
    aws_lb_target_group.backend_blue,
    aws_lb_target_group.backend_green
  ]

  lifecycle {
    ignore_changes = [default_action]
  }
}

resource "aws_lb_listener_rule" "backend" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_blue.arn
  }

  lifecycle {
    ignore_changes = [action]
  }
}
