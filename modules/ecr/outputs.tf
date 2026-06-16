output "repository_urls" {
  description = "Mapa nombre→URL de cada repositorio ECR (para usar en CI/CD y task definitions)"
  value       = { for name, repo in aws_ecr_repository.this : name => repo.repository_url }
}

output "repository_arns" {
  description = "Mapa nombre→ARN de cada repositorio ECR"
  value       = { for name, repo in aws_ecr_repository.this : name => repo.arn }
}
