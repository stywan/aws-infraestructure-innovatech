# =============================================================================
# Módulo: ecr
# Crea un repositorio Amazon ECR por cada servicio (frontend + backends).
# Las imágenes las publica el pipeline CI/CD (GitHub Actions) y las consumen
# las task definitions de ECS.
#
# - scan_on_push: análisis de vulnerabilidades al subir cada imagen.
# - lifecycle policy: conserva solo las últimas N imágenes para no acumular
#   costo/almacenamiento con cada despliegue del pipeline.
# =============================================================================

resource "aws_ecr_repository" "this" {
  for_each = toset(var.repository_names)

  name                 = each.value
  image_tag_mutability = "MUTABLE" # permite re-taggear "latest" en cada deploy

  image_scanning_configuration {
    scan_on_push = true
  }

  # En AWS Academy el lab se recrea; force_delete evita bloqueos al destruir.
  force_delete = true

  tags = {
    Name    = each.value
    Project = var.project_name
  }
}

# Conserva las últimas `max_image_count` imágenes; expira las más antiguas.
resource "aws_ecr_lifecycle_policy" "this" {
  for_each = aws_ecr_repository.this

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Conservar solo las ultimas ${var.max_image_count} imagenes"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.max_image_count
        }
        action = { type = "expire" }
      }
    ]
  })
}
