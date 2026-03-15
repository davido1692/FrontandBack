variable "vpc_id" {}
variable "public_subnets" { type = list(string) }

resource "aws_lb" "app" {
  name               = "app-alb"
  load_balancer_type = "application"
  subnets            = var.public_subnets
  security_groups    = []
}

resource "aws_lb_target_group" "blue" {
  name     = "frontend-blue-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path = "/health"
  }
}

resource "aws_lb_target_group" "green" {
  name     = "frontend-green-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = var.vpc_id

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
    target_group_arn = aws_lb_target_group.blue.arn
  }
}

output "alb_dns" { value = aws_lb.app.dns_name }
output "blue_tg_arn" { value = aws_lb_target_group.blue.arn }
output "green_tg_arn" { value = aws_lb_target_group.green.arn }
output "listener_arn" { value = aws_lb_listener.http.arn }
