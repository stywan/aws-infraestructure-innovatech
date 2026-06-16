# =============================================================================
# Innovatech Chile — EP3: Orquestación y automatización en AWS
# Arquitectura: ECS Fargate + ALB + RDS MySQL + ECR + CI/CD (GitHub Actions)
#
# Raíz de la configuración Terraform. Cablea los módulos en orden de
# dependencia. Se construye por fases:
#   Fase 1  ✅ networking (VPC, subredes, NAT, ruteo)
#   Fase 2  ✅ security, ecr, alb
#   Fase 3  ✅ secrets, rds, ecs (clúster, task definitions, services)
#   Fase 4  ✅ autoscaling (Target Tracking CPU, dentro del módulo ecs)
#   Fase 5  ⏳ CI/CD GitHub Actions (en los repos de front/back)
# =============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# -----------------------------------------------------------------------------
# Definición única de los servicios (puertos, repos ECR y routing del ALB).
# Reutilizada por security (puertos), ecr (repos) y alb (target groups/routing).
# -----------------------------------------------------------------------------
locals {
  frontend_port = 80

  # Cada backend: puerto del contenedor + rutas reales que expone el controller
  # Spring (@RequestMapping) que el ALB enruta + prioridad + esquema MySQL +
  # ruta de health check (un GET a esa ruta debe devolver 2xx/3xx).
  backends = {
    "despacho-backend" = {
      port              = 8081
      path_patterns     = ["/api/v1/despachos", "/api/v1/despachos/*"]
      priority          = 10
      db_name           = "despachos"
      health_check_path = "/api/v1/despachos"
    }
    "ventas-backend" = {
      port              = 8082
      path_patterns     = ["/api/v1/ventas", "/api/v1/ventas/*"]
      priority          = 20
      db_name           = "ventas"
      health_check_path = "/api/v1/ventas"
    }
  }

  # Todos los puertos de contenedor que el ALB debe poder alcanzar.
  container_ports = concat([local.frontend_port], [for b in local.backends : b.port])

  # Nombres de los repositorios ECR (frontend + un repo por backend).
  frontend_repo_name = "${var.project_name}-despacho-frontend"
  ecr_repository_names = concat(
    [local.frontend_repo_name],
    [for name, _ in local.backends : "${var.project_name}-${name}"]
  )

  # Mapa de servicios para ECS: frontend + backends, con la misma forma de objeto
  # (puerto, imagen ECR, target group, env vars y secrets).
  ecs_services = merge(
    {
      frontend = {
        container_port   = local.frontend_port
        image            = "${module.ecr.repository_urls[local.frontend_repo_name]}:${var.image_tag}"
        target_group_arn = module.alb.frontend_target_group_arn
        environment      = {}
        secrets          = {}
      }
    },
    {
      for name, b in local.backends : name => {
        container_port   = b.port
        image            = "${module.ecr.repository_urls["${var.project_name}-${name}"]}:${var.image_tag}"
        target_group_arn = module.alb.backend_target_group_arns[name]
        environment = {
          DB_ENDPOINT = module.rds.address
          DB_PORT     = tostring(module.rds.port)
          DB_NAME     = b.db_name
          DB_USERNAME = var.db_username
        }
        secrets = {
          DB_PASSWORD = module.secrets.parameter_arns["db/password"]
        }
      }
    }
  )
}

# -----------------------------------------------------------------------------
# Rol IAM de AWS Academy (pre-existente). En el Learner Lab no se pueden crear
# roles, así que reusamos LabRole como execution role y task role.
# (Un módulo IAM propio queda pendiente para un entorno sin esta restricción.)
# -----------------------------------------------------------------------------
data "aws_iam_role" "lab" {
  name = var.lab_role_name
}

# -----------------------------------------------------------------------------
# Fase 1 — Red base (VPC, subredes públicas/app/data, NAT, ruteo)
# -----------------------------------------------------------------------------
module "networking" {
  source                    = "./modules/networking"
  project_name              = var.project_name
  vpc_cidr                  = var.vpc_cidr
  availability_zones        = var.availability_zones
  public_subnet_cidrs       = var.public_subnet_cidrs
  private_app_subnet_cidrs  = var.private_app_subnet_cidrs
  private_data_subnet_cidrs = var.private_data_subnet_cidrs
}

# -----------------------------------------------------------------------------
# Fase 2 — Security Groups (ALB → ECS → RDS)
# -----------------------------------------------------------------------------
module "security" {
  source          = "./modules/security"
  project_name    = var.project_name
  vpc_id          = module.networking.vpc_id
  container_ports = local.container_ports
}

# -----------------------------------------------------------------------------
# Fase 2 — Repositorios ECR (uno por servicio)
# -----------------------------------------------------------------------------
module "ecr" {
  source           = "./modules/ecr"
  project_name     = var.project_name
  repository_names = local.ecr_repository_names
  max_image_count  = var.ecr_max_image_count
}

# -----------------------------------------------------------------------------
# Fase 2 — Application Load Balancer + target groups + routing por path
# -----------------------------------------------------------------------------
module "alb" {
  source            = "./modules/alb"
  project_name      = var.project_name
  vpc_id            = module.networking.vpc_id
  public_subnet_ids = module.networking.public_subnet_ids
  alb_sg_id         = module.security.alb_sg_id

  frontend = {
    port                 = local.frontend_port
    health_check_path    = var.frontend_health_check_path
    health_check_matcher = "200-399"
  }

  backends = {
    for name, b in local.backends : name => {
      port                 = b.port
      path_patterns        = b.path_patterns
      priority             = b.priority
      health_check_path    = b.health_check_path
      health_check_matcher = "200-399"
    }
  }
}

# -----------------------------------------------------------------------------
# Fase 3 — Secrets en SSM Parameter Store (credenciales de BD)
# -----------------------------------------------------------------------------
module "secrets" {
  source       = "./modules/secrets"
  project_name = var.project_name
  secret_names = ["db/password"]
  secret_values = {
    "db/password" = var.db_password
  }
}

# -----------------------------------------------------------------------------
# Fase 3 — Base de datos RDS MySQL (subredes privadas Data)
# -----------------------------------------------------------------------------
module "rds" {
  source                  = "./modules/rds"
  project_name            = var.project_name
  private_data_subnet_ids = module.networking.private_data_subnet_ids
  rds_sg_id               = module.security.rds_sg_id
  db_username             = var.db_username
  db_password             = var.db_password
  instance_class          = var.db_instance_class
}

# -----------------------------------------------------------------------------
# Fase 3 — Clúster ECS Fargate + services + autoscaling
# -----------------------------------------------------------------------------
module "ecs" {
  source                 = "./modules/ecs"
  project_name           = var.project_name
  aws_region             = var.aws_region
  execution_role_arn     = data.aws_iam_role.lab.arn
  task_role_arn          = data.aws_iam_role.lab.arn
  private_app_subnet_ids = module.networking.private_app_subnet_ids
  ecs_sg_id              = module.security.ecs_sg_id
  services               = local.ecs_services

  # El ALB (listener + reglas) debe existir antes de crear los services,
  # porque cada target group debe estar asociado al balanceador.
  depends_on = [module.alb]
}
