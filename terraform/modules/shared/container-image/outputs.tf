output "image_reference" {
  description = "Immutable <repository>:<content-hash> reference of the built (and pushed) image."
  value       = local.image_reference
  depends_on  = [docker_registry_image.this]
}

output "image_id" {
  description = "Local Docker image ID."
  value       = docker_image.this.image_id
}
