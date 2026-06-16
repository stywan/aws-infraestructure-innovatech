# =============================================================================
# Módulo: ecs
# Clúster ECS Fargate + por cada servicio (frontend/backends):
#   - CloudWatch Log Group           (IE6: logs)
#   - Task Definition (Fargate)      (IE2: imagen ECR, env vars, secrets)
#   - ECS Service enlazado al ALB    (IE2/IE7: despliegue y comunicación)
#   - Autoscaling Target Tracking    (IE3: escalado por CPU)
#
# Las tareas corren en subredes privadas (sin IP pública) y salen a internet
# vía NAT para descargar imágenes de ECR y enviar logs a CloudWatch.
# =============================================================================

# -----------------------------------------------------------------------------
# Clúster ECS
# -----------------------------------------------------------------------------
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = {
    Name    = "${var.project_name}-cluster"
    Project = var.project_name
  }
}

# Proveedor de capacidad: Fargate (y Fargate Spot disponible si se quisiera).
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}

# -----------------------------------------------------------------------------
# Log Groups (uno por servicio)
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "service" {
  for_each = var.services

  name              = "/ecs/${var.project_name}/${each.key}"
  retention_in_days = var.log_retention_days

  tags = {
    Name    = "/ecs/${var.project_name}/${each.key}"
    Project = var.project_name
  }
}

# -----------------------------------------------------------------------------
# Task Definitions (Fargate, awsvpc)
# -----------------------------------------------------------------------------
resource "aws_ecs_task_definition" "service" {
  for_each = var.services

  family                   = "${var.project_name}-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = each.key
      image     = each.value.image
      essential = true

      portMappings = [
        {
          containerPort = each.value.container_port
          protocol      = "tcp"
        }
      ]

      # Variables de entorno NO sensibles (host RDS, nombre BD, URLs, etc.)
      environment = [
        for k, v in each.value.environment : { name = k, value = v }
      ]

      # Secrets: se resuelven desde SSM en arranque (no quedan en texto plano)
      secrets = [
        for k, arn in each.value.secrets : { name = k, valueFrom = arn }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.service[each.key].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name    = "${var.project_name}-${each.key}"
    Project = var.project_name
  }
}

# -----------------------------------------------------------------------------
# ECS Services (enlazados a su target group del ALB)
# -----------------------------------------------------------------------------
resource "aws_ecs_service" "service" {
  for_each = var.services

  name            = "${var.project_name}-${each.key}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.service[each.key].arn
  desired_count   = each.value.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_app_subnet_ids
    security_groups  = [var.ecs_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = each.value.target_group_arn
    container_name   = each.key
    container_port   = each.value.container_port
  }

  # Da margen a que la tarea pase el health check del ALB antes de contarla.
  health_check_grace_period_seconds = 60

  # El pipeline CI/CD actualiza la task definition y el autoscaling cambia el
  # desired_count: Terraform no debe revertir esos cambios fuera de banda.
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

  tags = {
    Name    = "${var.project_name}-${each.key}"
    Project = var.project_name
  }
}

# -----------------------------------------------------------------------------
# Autoscaling — Target Tracking por CPU (IE3)
# -----------------------------------------------------------------------------
resource "aws_appautoscaling_target" "service" {
  for_each = var.services

  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.service[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = each.value.autoscaling_min
  max_capacity       = each.value.autoscaling_max
}

resource "aws_appautoscaling_policy" "cpu" {
  for_each = var.services

  name               = "${var.project_name}-${each.key}-cpu-tracking"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.service[each.key].service_namespace
  resource_id        = aws_appautoscaling_target.service[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.service[each.key].scalable_dimension

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = each.value.autoscaling_cpu_target
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}
