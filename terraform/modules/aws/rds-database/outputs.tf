output "host" {
  description = "Endpoint host name of the instance."
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Endpoint port of the instance."
  value       = aws_db_instance.this.port
}

output "identifier" {
  description = "RDS instance identifier."
  value       = aws_db_instance.this.identifier
}
