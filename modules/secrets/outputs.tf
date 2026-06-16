output "parameter_arns" {
  description = "Mapa nombre→ARN de cada parámetro SSM (para el bloque secrets de las task definitions)"
  value       = { for k, p in aws_ssm_parameter.this : k => p.arn }
}
