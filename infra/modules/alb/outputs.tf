output "alb_dns" {
  value = aws_lb.app.dns_name
}

output "blue_tg_arn" {
  value = aws_lb_target_group.frontend_blue.arn
}

output "green_tg_arn" {
  value = aws_lb_target_group.frontend_green.arn
}

output "backend_blue_tg_arn" {
  value = aws_lb_target_group.backend_blue.arn
}

output "backend_green_tg_arn" {
  value = aws_lb_target_group.backend_green.arn
}

output "listener_arn" {
  value = aws_lb_listener.http.arn
}
