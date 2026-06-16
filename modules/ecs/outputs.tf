output "cluster_name" {
  description = "Nombre del clúster ECS"
  value       = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  description = "ARN del clúster ECS"
  value       = aws_ecs_cluster.main.arn
}

output "service_names" {
  description = "Mapa nombre lógico→nombre del ECS service (para usar en CI/CD: aws ecs update-service)"
  value       = { for k, s in aws_ecs_service.service : k => s.name }
}

output "task_definition_families" {
  description = "Mapa nombre lógico→familia de la task definition"
  value       = { for k, t in aws_ecs_task_definition.service : k => t.family }
}

output "log_group_names" {
  description = "Mapa nombre lógico→log group de CloudWatch"
  value       = { for k, lg in aws_cloudwatch_log_group.service : k => lg.name }
}
