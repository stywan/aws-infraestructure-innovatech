variable "project_name" {
  description = "Nombre del proyecto, usado como prefijo"
  type        = string
}

variable "aws_region" {
  description = "Región AWS (para la configuración de logs awslogs)"
  type        = string
}

variable "execution_role_arn" {
  description = "ARN del execution role de ECS (pull de ECR, escritura de logs, lectura de secrets SSM)"
  type        = string
}

variable "task_role_arn" {
  description = "ARN del task role de ECS (permisos del contenedor en runtime)"
  type        = string
}

variable "private_app_subnet_ids" {
  description = "IDs de las subredes privadas donde corren las tareas Fargate"
  type        = list(string)
}

variable "ecs_sg_id" {
  description = "ID del Security Group de las tareas ECS"
  type        = string
}

variable "log_retention_days" {
  description = "Días de retención de los log groups de CloudWatch"
  type        = number
  default     = 7
}

variable "enable_container_insights" {
  description = "Habilitar CloudWatch Container Insights en el clúster (métricas extra)"
  type        = bool
  default     = true
}

variable "health_check_grace_period_seconds" {
  description = "Segundos de gracia antes de que el ALB cuente health checks (debe superar el tiempo de arranque de la app)"
  type        = number
  default     = 180
}

variable "services" {
  description = <<-EOT
    Mapa de servicios a desplegar. Clave = nombre del servicio. Cada valor:
    - container_port:         puerto que expone el contenedor
    - image:                  URL completa de la imagen (repo ECR:tag)
    - target_group_arn:       target group del ALB al que se enlaza
    - desired_count:          número inicial de tareas
    - cpu / memory:           unidades CPU (256=0.25 vCPU) y memoria MB de la task
    - environment:            mapa de env vars NO sensibles
    - secrets:                mapa nombre→ARN de parámetro SSM (sensibles)
    - autoscaling_min/max:    límites de tareas para el autoscaling
    - autoscaling_cpu_target: % de CPU objetivo del Target Tracking
  EOT
  type = map(object({
    container_port         = number
    image                  = string
    target_group_arn       = string
    desired_count          = optional(number, 1)
    cpu                    = optional(number, 256)
    memory                 = optional(number, 512)
    environment            = optional(map(string), {})
    secrets                = optional(map(string), {})
    autoscaling_min        = optional(number, 1)
    autoscaling_max        = optional(number, 3)
    autoscaling_cpu_target = optional(number, 50)
  }))
}
