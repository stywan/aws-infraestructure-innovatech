variable "project_name" {
  description = "Nombre del proyecto, usado como prefijo"
  type        = string
}

variable "private_data_subnet_ids" {
  description = "IDs de las subredes privadas Data donde vive RDS (una por AZ)"
  type        = list(string)
}

variable "rds_sg_id" {
  description = "ID del Security Group de RDS"
  type        = string
}

variable "engine_version" {
  description = "Versión del motor MySQL"
  type        = string
  default     = "8.0"
}

variable "instance_class" {
  description = "Clase de instancia RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Almacenamiento inicial en GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Tope de autoescalado de almacenamiento en GB"
  type        = number
  default     = 50
}

variable "initial_db_name" {
  description = "Nombre de la base de datos inicial creada con la instancia"
  type        = string
  default     = "innovatech"
}

variable "db_username" {
  description = "Usuario maestro de la base de datos"
  type        = string
}

variable "db_password" {
  description = "Contraseña del usuario maestro"
  type        = string
  sensitive   = true
}

variable "multi_az" {
  description = "Habilitar Multi-AZ (alta disponibilidad). En AWS Academy puede no estar permitido"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Días de retención de backups automáticos"
  type        = number
  default     = 1
}
