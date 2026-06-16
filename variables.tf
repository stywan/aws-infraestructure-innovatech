variable "aws_region" {
  description = "AWS region para desplegar la infraestructura"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nombre del proyecto, usado como prefijo en todos los recursos"
  type        = string
  default     = "innovatech"
}

# -----------------------------------------------------------------------------
# Red
# -----------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "CIDR block de la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Zonas de disponibilidad a usar (2 AZs para alta disponibilidad)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDRs de subredes públicas (ALB), uno por AZ"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.4.0/24"]
}

variable "private_app_subnet_cidrs" {
  description = "CIDRs de subredes privadas (tareas ECS), uno por AZ"
  type        = list(string)
  default     = ["10.0.2.0/24", "10.0.5.0/24"]
}

variable "private_data_subnet_cidrs" {
  description = "CIDRs de subredes privadas (RDS), uno por AZ"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.6.0/24"]
}

# -----------------------------------------------------------------------------
# ECR
# -----------------------------------------------------------------------------
variable "ecr_max_image_count" {
  description = "Número máximo de imágenes a conservar por repositorio ECR"
  type        = number
  default     = 10
}

# -----------------------------------------------------------------------------
# Health checks del ALB
# -----------------------------------------------------------------------------
variable "frontend_health_check_path" {
  description = "Ruta del health check del frontend en el target group"
  type        = string
  default     = "/"
}

# -----------------------------------------------------------------------------
# IAM (AWS Academy)
# -----------------------------------------------------------------------------
variable "lab_role_name" {
  description = "Nombre del rol pre-existente de AWS Academy usado como execution/task role"
  type        = string
  default     = "LabRole"
}

# -----------------------------------------------------------------------------
# Base de datos RDS
# -----------------------------------------------------------------------------
variable "db_username" {
  description = "Usuario maestro de la base de datos MySQL"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Contraseña del usuario maestro de MySQL (definir en terraform.tfvars, NO versionar)"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "Clase de instancia de RDS"
  type        = string
  default     = "db.t3.micro"
}

# -----------------------------------------------------------------------------
# Imágenes de contenedor
# -----------------------------------------------------------------------------
variable "image_tag" {
  description = "Tag de las imágenes ECR a desplegar inicialmente (el CI/CD luego despliega por SHA)"
  type        = string
  default     = "latest"
}
