output "host" {
  description = "Server host name (available once the database and firewall rules exist)."
  value       = module.endpoint.host
  depends_on = [
    azurerm_mssql_database.this,
    azurerm_mssql_firewall_rule.this,
  ]
}

output "port" {
  description = "Server port."
  value       = module.endpoint.port
}

output "server_name" {
  description = "Logical server name."
  value       = azurerm_mssql_server.this.name
}

output "database_id" {
  description = "Application database resource ID."
  value       = azurerm_mssql_database.this.id
}
