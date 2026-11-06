output "api_runtimes" {
  description = "Deployable API runtimes keyed by runtime code (csharp | kotlin)."
  value       = local.api_runtimes
}

output "database_engines" {
  description = "Deployable database engines keyed by provider code (ms | pg), matching the /api/{provider}/v1 route segment."
  value       = local.database_engines
}

output "sample_resource_path" {
  description = "Representative REST resource path appended to /api/{provider} for smoke tests."
  value       = local.sample_resource_path
}
