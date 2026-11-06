output "host" {
  description = "Server host name (available once the database and firewall rules exist)."
  value       = module.endpoint.host
  depends_on = [
    azurerm_postgresql_flexible_server_database.this,
    azurerm_postgresql_flexible_server_firewall_rule.this,
  ]
}

output "port" {
  description = "Server port."
  value       = module.endpoint.port
}

output "server_name" {
  description = "Server name."
  value       = azurerm_postgresql_flexible_server.this.name
}

output "database_id" {
  description = "Application database resource ID."
  value       = azurerm_postgresql_flexible_server_database.this.id
}
