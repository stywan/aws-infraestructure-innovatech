# Innovatech Chile — EP3: Orquestación y automatización en AWS

Infraestructura como código (Terraform) para desplegar la aplicación de Innovatech
sobre **Amazon ECS Fargate**, con balanceo (ALB), base de datos gestionada (RDS MySQL),
registro de imágenes (ECR), autoscaling, logs centralizados (CloudWatch) y un
pipeline **CI/CD con GitHub Actions** (build → push → deploy).

Continúa el trabajo de EP1 (infra base en EC2) y EP2 (contenedorización), evolucionando
hacia un entorno **escalable, tolerante a fallos y automatizable**.

---

## Arquitectura

```
                          Internet
                             │  HTTP :80
                             ▼
                  ┌────────────────────────┐
                  │  Application Load       │  (subredes públicas, 2 AZ)
                  │  Balancer (ALB)         │
                  └───────────┬─────────────┘
        ┌─────────────────────┼──────────────────────────┐
        │ (default)           │ /api/v1/despachos*        │ /api/v1/ventas*
        ▼                     ▼                           ▼
  ┌───────────┐        ┌───────────────┐          ┌───────────────┐
  │ frontend  │        │ despacho-back │          │ ventas-back   │   ECS Fargate
  │ :80 (SPA) │        │ :8081         │          │ :8082         │   (subredes
  └───────────┘        └───────┬───────┘          └───────┬───────┘   privadas app)
                               │  3306                     │
                               └────────────┬──────────────┘
                                            ▼
                                   ┌──────────────────┐
                                   │  RDS MySQL        │  (subredes privadas data, 2 AZ)
                                   │  esquemas:        │
                                   │  despachos/ventas │
                                   └──────────────────┘

  ECR: 3 repos · CloudWatch Logs: 3 grupos · Autoscaling: Target Tracking CPU 50%
```

- **Origen único:** el navegador carga la SPA desde el ALB y llama a los backends por
  el **mismo dominio** (`/api/v1/...`). El ALB enruta por *path* a cada servicio ECS,
  por lo que los backends nunca se exponen directamente a internet (sin CORS).
- **Alta disponibilidad:** todo se reparte en 2 zonas de disponibilidad.
- **Salida a internet de las tareas:** las tareas viven en subredes privadas y usan
  **NAT Gateway** para descargar imágenes de ECR y enviar logs a CloudWatch.

---

## Estructura del repositorio

```
.
├── main.tf                  # raíz: locals (servicios/puertos) + cableado de módulos
├── variables.tf             # variables de entrada
├── outputs.tf               # ALB DNS, ECR URLs, nombres de servicios ECS, etc.
├── terraform.tfvars.example # plantilla de variables (copiar a terraform.tfvars)
└── modules/
    ├── networking/  VPC, 6 subredes (public/app/data ×2 AZ), IGW, 2 NAT, ruteo
    ├── security/    3 Security Groups encadenados (ALB → ECS → RDS)
    ├── ecr/         3 repositorios con scan-on-push y lifecycle policy
    ├── alb/         ALB + target groups + routing por path
    ├── secrets/     credenciales de BD en SSM Parameter Store (SecureString)
    ├── rds/         instancia MySQL en subredes privadas
    └── ecs/         clúster Fargate + task definitions + services + autoscaling
```

---

## Requisitos previos

- Terraform >= 1.5
- AWS CLI configurado con las **credenciales temporales** del Learner Lab de AWS Academy
  (`aws configure` o variables de entorno `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`,
  `AWS_SESSION_TOKEN`). Caducan cada ~3-4 h.
- Rol `LabRole` disponible en la cuenta (se reutiliza como execution/task role de ECS;
  en Academy no se pueden crear roles IAM nuevos).

---

## Despliegue

> El orden importa: primero la infraestructura, luego las imágenes vía CI/CD.

### 1. Provisionar la infraestructura

```bash
cp terraform.tfvars.example terraform.tfvars   # y edita db_password, etc.
terraform init
terraform plan
terraform apply
```

Al terminar, anota los outputs:

```bash
terraform output web_url            # URL pública (frontend)
terraform output ecr_repository_urls
terraform output ecs_service_names
```

> En este punto los servicios ECS intentarán arrancar pero **fallarán el pull**
> porque ECR aún está vacío. Es esperado: ECS reintenta hasta que el pipeline
> publique las imágenes (paso 3).

### 2. Configurar los secrets de GitHub Actions

En **cada** repo de aplicación (`innovatech-despacho-frontend`,
`innovatech-despacho-backend`, `innovatech-ventas-backend`):

`Settings → Secrets and variables → Actions → New repository secret`

| Secret                  | Valor                                                        | Repos          |
|-------------------------|--------------------------------------------------------------|----------------|
| `AWS_ACCESS_KEY_ID`     | de "AWS Details" del Learner Lab                             | los 3          |
| `AWS_SECRET_ACCESS_KEY` | de "AWS Details" del Learner Lab                             | los 3          |
| `AWS_SESSION_TOKEN`     | de "AWS Details" del Learner Lab (token de sesión temporal)  | los 3          |
| `ALB_URL`               | output `web_url`, ej. `http://innovatech-alb-xxxx.elb.amazonaws.com` | solo frontend  |

> Las credenciales de Academy expiran: **actualízalas antes de cada demo**.

### 3. Disparar el pipeline (build → push → deploy)

Un `push` a `main` en cualquiera de los repos (o "Run workflow" manual) ejecuta:

1. Build de la imagen Docker (stage `production`).
2. Push a Amazon ECR (`sha-<commit>` + `latest`).
3. Registro de nueva revisión de la Task Definition con esa imagen y despliegue
   rolling en el servicio ECS (espera estabilidad del servicio).

Repite para los 3 repos. Tras el primer deploy de cada uno, las tareas quedan
estables y la app es accesible en `web_url`.

---

## Validación funcional

```bash
ALB=$(terraform output -raw web_url)

curl -i "$ALB/"                      # SPA del frontend (200)
curl -i "$ALB/api/v1/despachos"      # backend despacho vía ALB (200)
curl -i "$ALB/api/v1/ventas"         # backend ventas vía ALB (200)
```

- **Logs:** CloudWatch → Log groups `/ecs/innovatech/<servicio>`.
- **Recuperación ante fallos:** detén una tarea (`aws ecs stop-task ...` o desde la
  consola) y ECS levanta una nueva automáticamente para mantener el `desired_count`.
- **Autoscaling:** genera carga de CPU (p. ej. con un test de carga contra un endpoint);
  el Target Tracking sube el número de tareas al superar el 50 % de CPU promedio.

---

## Decisiones técnicas (para la defensa)

- **ECS Fargate** sobre EKS: sin gestión de nodos, menor superficie de error y encaje
  natural con el laboratorio de AWS Academy (IAM restringido, sin control plane de pago).
- **Origen único vía ALB + routing por path:** simplifica CORS y no expone backends.
- **Secrets en SSM SecureString** referenciados por la task definition: las credenciales
  nunca quedan en texto plano en la task definition ni en el repositorio (IE5).
- **`lifecycle { ignore_changes = [task_definition, desired_count] }`** en los services:
  el pipeline CI/CD y el autoscaling cambian esos valores fuera de Terraform y no deben
  ser revertidos en el siguiente `apply`.
- **Reutilización de `LabRole`:** en Academy no se pueden crear roles; un módulo IAM
  propio (execution/task roles dedicados) queda como mejora para un entorno productivo.

---

## Limpieza

```bash
terraform destroy
```

> Los repositorios ECR usan `force_delete = true` para poder destruirlos aunque
> contengan imágenes.
