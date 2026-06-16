output "alb_dns_name" {
  description = "DNS público del ALB (URL de acceso al frontend)"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN del Application Load Balancer"
  value       = aws_lb.main.arn
}

output "frontend_target_group_arn" {
  description = "ARN del target group del frontend (para enlazar el ECS service)"
  value       = aws_lb_target_group.frontend.arn
}

output "backend_target_group_arns" {
  description = "Mapa nombre→ARN de los target groups de backends (para enlazar cada ECS service)"
  value       = { for k, tg in aws_lb_target_group.backend : k => tg.arn }
}

output "listener_arn" {
  description = "ARN del listener HTTP :80"
  value       = aws_lb_listener.http.arn
}
