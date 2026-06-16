variable "project_name" {
  description = "Nombre del proyecto, usado como prefijo de los parámetros SSM"
  type        = string
}

variable "secret_names" {
  description = "Lista de nombres de secretos a crear (no sensible: se usa en for_each)"
  type        = list(string)
}

variable "secret_values" {
  description = "Mapa nombre→valor de los secretos (sensible). Debe contener cada secret_names"
  type        = map(string)
  sensitive   = true
}
