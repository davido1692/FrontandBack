resource "aws_lb" "app" {
  name               = var.name
  load_balancer_type = "application"
  subnets            = var.public_subnets
  security_groups    = var.security_group_ids
}

resource "aws_lb_target_group" "frontend_blue" {
  name        = "${var.name}-fe-blue-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group" "frontend_green" {
  name        = "${var.name}-fe-green-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group" "backend_blue" {
  name        = "${var.name}-be-blue-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group" "backend_green" {
  name        = "${var.name}-be-green-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
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
    type = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.backend_blue.arn
        weight = 100
      }
      target_group {
        arn    = aws_lb_target_group.backend_green.arn
        weight = 0
      }
    }
  }

  lifecycle {
    ignore_changes = [action]
  }
}

resource "aws_lb_listener_rule" "frontend_green_assoc" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 999

  condition {
    http_header {
      http_header_name = "X-Deploy-Target"
      values           = ["frontend-green"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_green.arn
  }
}

resource "aws_lb_listener_rule" "backend_green_assoc" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 998

  condition {
    http_header {
      http_header_name = "X-Deploy-Target"
      values           = ["backend-green"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_green.arn
  }
}
