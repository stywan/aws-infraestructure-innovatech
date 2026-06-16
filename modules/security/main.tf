# =============================================================================
# Módulo: security
# Define los 3 Security Groups que modelan el flujo de tráfico de la
# arquitectura orquestada:
#
#   Internet ──80──▶ [alb_sg]  ──(puertos contenedor)──▶ [ecs_sg] ──3306──▶ [rds_sg]
#
# Principio: cada capa solo acepta tráfico de la capa inmediatamente anterior
# (referenciando Security Groups, no CIDRs), minimizando la superficie expuesta.
# =============================================================================

# -----------------------------------------------------------------------------
# SG del Application Load Balancer — única puerta de entrada desde internet
# -----------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Permite HTTP/HTTPS entrante desde internet hacia el ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP desde internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS desde internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Todo el trafico saliente (hacia tareas ECS)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-alb-sg"
    Tier    = "public"
    Project = var.project_name
  }
}

# -----------------------------------------------------------------------------
# SG de las tareas ECS Fargate — solo acepta tráfico desde el ALB
# Reglas de ingreso separadas (no inline) para poder referenciar el SG del ALB.
# -----------------------------------------------------------------------------
resource "aws_security_group" "ecs" {
  name        = "${var.project_name}-ecs-sg"
  description = "Permite trafico desde el ALB hacia los contenedores"
  vpc_id      = var.vpc_id

  egress {
    description = "Todo el trafico saliente (ECR, RDS, CloudWatch via NAT)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-ecs-sg"
    Tier    = "app"
    Project = var.project_name
  }
}

# Una regla de ingreso por puerto de contenedor (frontend + backends),
# todas con origen el SG del ALB.
resource "aws_security_group_rule" "ecs_from_alb" {
  for_each = toset([for p in var.container_ports : tostring(p)])

  type                     = "ingress"
  description              = "ALB -> contenedor puerto ${each.value}"
  from_port                = tonumber(each.value)
  to_port                  = tonumber(each.value)
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ecs.id
  source_security_group_id = aws_security_group.alb.id
}

# -----------------------------------------------------------------------------
# SG de RDS MySQL — solo acepta 3306 desde las tareas ECS (backends)
# -----------------------------------------------------------------------------
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Permite MySQL (3306) solo desde las tareas ECS"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL desde tareas ECS"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  egress {
    description = "Todo el trafico saliente"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-rds-sg"
    Tier    = "data"
    Project = var.project_name
  }
}
