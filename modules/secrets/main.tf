# =============================================================================
# Módulo: secrets
# Guarda credenciales sensibles en AWS SSM Parameter Store como SecureString
# (cifrado con la KMS key gestionada por AWS `alias/aws/ssm`).
#
# Las task definitions de ECS referencian estos parámetros por su ARN en el
# bloque `secrets` → el valor NUNCA queda escrito en la task definition ni en
# variables de entorno en texto plano (cumple IE5: gestión segura de secrets).
# El execution role de ECS es quien los resuelve en tiempo de arranque.
# =============================================================================

resource "aws_ssm_parameter" "this" {
  for_each = toset(var.secret_names)

  name        = "/${var.project_name}/${each.value}"
  description = "Secret ${each.value} para ${var.project_name} (EP3)"
  type        = "SecureString"
  value       = var.secret_values[each.value]

  tags = {
    Project = var.project_name
  }
}
