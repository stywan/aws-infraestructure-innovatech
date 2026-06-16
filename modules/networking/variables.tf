variable "project_name" {
  description = "Nombre del proyecto, usado como prefijo en los recursos de red"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block de la VPC (ej: 10.0.0.0/16)"
  type        = string
}

variable "availability_zones" {
  description = "Lista de zonas de disponibilidad (ej: [\"us-east-1a\", \"us-east-1b\"])"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDRs de subredes públicas (ALB), uno por AZ (ej: [\"10.0.1.0/24\", \"10.0.4.0/24\"])"
  type        = list(string)
}

variable "private_app_subnet_cidrs" {
  description = "CIDRs de subredes privadas para tareas ECS, uno por AZ (ej: [\"10.0.2.0/24\", \"10.0.5.0/24\"])"
  type        = list(string)
}

variable "private_data_subnet_cidrs" {
  description = "CIDRs de subredes privadas para RDS, uno por AZ (ej: [\"10.0.3.0/24\", \"10.0.6.0/24\"])"
  type        = list(string)
}
