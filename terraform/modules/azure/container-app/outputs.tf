output "fqdn" {
  description = "Public ingress FQDN of the app."
  value       = azurerm_container_app.this.ingress[0].fqdn
}

output "name" {
  description = "Container App name."
  value       = azurerm_container_app.this.name
}
