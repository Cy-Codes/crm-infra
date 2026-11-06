output "deployment_id" {
  description = "Identifier of the latest schema deployment; depend on it to start workloads only after the schema exists."
  value       = terraform_data.schema.id
}
