variable "project_name" {
  description = "Nombre del proyecto, usado como prefijo en el ALB y target groups"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs de las subredes públicas donde se ubica el ALB (una por AZ)"
  type        = list(string)
}

variable "alb_sg_id" {
  description = "ID del Security Group del ALB"
  type        = string
}

variable "frontend" {
  description = "Configuración del target group del frontend (acción por defecto)"
  type = object({
    port                 = number
    health_check_path    = optional(string, "/")
    health_check_matcher = optional(string, "200-399")
  })
}

variable "backends" {
  description = <<-EOT
    Mapa de servicios backend → su target group y routing.
    - port: puerto del contenedor
    - path_patterns: rutas que enruta el ALB hacia este backend (ej: ["/api/despacho*"])
    - priority: prioridad de la regla del listener (única, menor = se evalúa antes)
    - health_check_path/matcher: health check del target group
  EOT
  type = map(object({
    port                 = number
    path_patterns        = list(string)
    priority             = number
    health_check_path    = optional(string, "/")
    health_check_matcher = optional(string, "200-399")
  }))
}
