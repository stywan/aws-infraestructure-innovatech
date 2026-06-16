output "endpoint" {
  description = "Endpoint host:puerto de la instancia RDS"
  value       = aws_db_instance.mysql.endpoint
}

output "address" {
  description = "Hostname (DNS) de la instancia RDS — usar como DB_ENDPOINT"
  value       = aws_db_instance.mysql.address
}

output "port" {
  description = "Puerto de la instancia RDS"
  value       = aws_db_instance.mysql.port
}

output "db_name" {
  description = "Nombre de la base de datos inicial"
  value       = aws_db_instance.mysql.db_name
}
