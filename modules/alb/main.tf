# =============================================================================
# Módulo: alb
# Application Load Balancer público + routing por path hacia los servicios ECS.
#
#   Internet ─80─▶ ALB
#                   ├── (default)        ──▶ TG frontend  (puerto contenedor frontend)
#                   ├── /api/despacho*   ──▶ TG despacho-backend
#                   └── /api/ventas*     ──▶ TG ventas-backend
#
# Los target groups usan target_type = "ip" porque las tareas Fargate
# (modo de red awsvpc) se registran por su IP privada, no por instancia.
# El frontend llama a los backends a través de la MISMA URL pública del ALB
# (rutas /api/...), evitando exponer los backends directamente.
# =============================================================================

# -----------------------------------------------------------------------------
# Load Balancer (en las 2 subredes públicas para alta disponibilidad)
# -----------------------------------------------------------------------------
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  tags = {
    Name    = "${var.project_name}-alb"
    Project = var.project_name
  }
}

# -----------------------------------------------------------------------------
# Target Group del FRONTEND (acción por defecto del listener)
# -----------------------------------------------------------------------------
resource "aws_lb_target_group" "frontend" {
  name        = "${var.project_name}-tg-frontend"
  port        = var.frontend.port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = var.frontend.health_check_path
    matcher             = var.frontend.health_check_matcher
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name    = "${var.project_name}-tg-frontend"
    Project = var.project_name
  }
}

# -----------------------------------------------------------------------------
# Target Groups de los BACKENDS (uno por servicio)
# -----------------------------------------------------------------------------
resource "aws_lb_target_group" "backend" {
  for_each = var.backends

  name        = "${var.project_name}-tg-${each.key}"
  port        = each.value.port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = each.value.health_check_path
    matcher             = each.value.health_check_matcher
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name    = "${var.project_name}-tg-${each.key}"
    Project = var.project_name
  }
}

# -----------------------------------------------------------------------------
# Listener HTTP :80 — por defecto enruta al frontend
# -----------------------------------------------------------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# -----------------------------------------------------------------------------
# Reglas de routing por path → cada backend
# -----------------------------------------------------------------------------
resource "aws_lb_listener_rule" "backend" {
  for_each = var.backends

  listener_arn = aws_lb_listener.http.arn
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend[each.key].arn
  }

  condition {
    path_pattern {
      values = each.value.path_patterns
    }
  }
}
