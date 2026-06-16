variable "project_name" {
  description = "Nombre del proyecto, usado como prefijo en los Security Groups"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC donde se crean los Security Groups"
  type        = string
}

variable "container_ports" {
  description = "Puertos de contenedor que el ALB debe poder alcanzar (frontend + backends)"
  type        = list(number)
}
