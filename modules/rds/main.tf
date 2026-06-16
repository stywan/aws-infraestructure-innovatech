# =============================================================================
# Módulo: rds
# Instancia Amazon RDS MySQL en las subredes privadas Data (sin acceso público).
# Solo accesible desde las tareas ECS (vía rds-sg, puerto 3306).
#
# Una sola instancia aloja los esquemas de ambos backends (despachos y ventas).
# Los backends Spring Boot deben crear su esquema con
# `?createDatabaseIfNotExist=true` en la URL JDBC, o crearse manualmente.
# =============================================================================

# Grupo de subredes: RDS se despliega en las subredes privadas Data (2 AZ).
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.private_data_subnet_ids

  tags = {
    Name    = "${var.project_name}-db-subnet-group"
    Project = var.project_name
  }
}

resource "aws_db_instance" "mysql" {
  identifier     = "${var.project_name}-mysql"
  engine         = "mysql"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.initial_db_name
  username = var.db_username
  password = var.db_password
  port     = 3306

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_sg_id]
  multi_az               = var.multi_az
  publicly_accessible    = false

  # Apto para entorno académico: sin réplicas de backup largas, destrucción simple.
  backup_retention_period = var.backup_retention_period
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = {
    Name    = "${var.project_name}-mysql"
    Tier    = "data"
    Project = var.project_name
  }
}
