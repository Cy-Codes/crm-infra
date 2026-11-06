output "environment" {
  description = "Non-secret environment variables per API runtime (csharp | kotlin)."
  value       = local.environment
}

output "secrets" {
  description = "Secret environment variables per API runtime (csharp | kotlin); store them in the cloud's secret manager."
  value       = local.secrets
  sensitive   = true
}

output "secret_names" {
  description = "Names of the secret environment variables per API runtime, safe to use in for_each."
  value       = local.secret_names
}
