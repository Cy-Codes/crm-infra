output "host" {
  description = "Host name portion of the address."
  value       = local.host
}

output "port" {
  description = "Port portion of the address (or the default port)."
  value       = local.port
}
