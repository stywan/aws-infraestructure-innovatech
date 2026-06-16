# =============================================================================
# Outputs — se irán ampliando por fase (ECR URLs, ALB DNS, RDS endpoint, etc.)
# =============================================================================

# --- Red (Fase 1) ---
output "vpc_id" {
  description = "ID de la VPC creada"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "IDs de las subredes públicas (ALB) por AZ"
  value       = module.networking.public_subnet_ids
}

output "private_app_subnet_ids" {
  description = "IDs de las subredes privadas App (tareas ECS) por AZ"
  value       = module.networking.private_app_subnet_ids
}

output "private_data_subnet_ids" {
  description = "IDs de las subredes privadas Data (RDS) por AZ"
  value       = module.networking.private_data_subnet_ids
}

# --- Security Groups (Fase 2) ---
output "security_group_ids" {
  description = "IDs de los Security Groups (alb, ecs, rds)"
  value = {
    alb = module.security.alb_sg_id
    ecs = module.security.ecs_sg_id
    rds = module.security.rds_sg_id
  }
}

# --- ECR (Fase 2) ---
output "ecr_repository_urls" {
  description = "URLs de los repositorios ECR (usar en CI/CD y task definitions)"
  value       = module.ecr.repository_urls
}

# --- ALB (Fase 2) ---
output "alb_dns_name" {
  description = "DNS público del ALB — URL de acceso al frontend"
  value       = module.alb.alb_dns_name
}

output "web_url" {
  description = "URL pública de la aplicación (frontend vía ALB)"
  value       = "http://${module.alb.alb_dns_name}"
}

# --- RDS (Fase 3) ---
output "rds_endpoint" {
  description = "Endpoint de la instancia RDS MySQL"
  value       = module.rds.address
}

# --- ECS (Fase 3) ---
output "ecs_cluster_name" {
  description = "Nombre del clúster ECS"
  value       = module.ecs.cluster_name
}

output "ecs_service_names" {
  description = "Nombres de los ECS services (para CI/CD: aws ecs update-service --service ...)"
  value       = module.ecs.service_names
}

output "ecs_log_groups" {
  description = "Log groups de CloudWatch por servicio"
  value       = module.ecs.log_group_names
}
