variable "project_name" {
  description = "Nombre del proyecto, usado como tag en los repositorios"
  type        = string
}

variable "repository_names" {
  description = "Lista de nombres de repositorios ECR a crear (uno por servicio)"
  type        = list(string)
}

variable "max_image_count" {
  description = "Número máximo de imágenes a conservar por repositorio (lifecycle)"
  type        = number
  default     = 10
}
