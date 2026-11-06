output "cloud" {
  description = "Cloud provider of this stack."
  value       = "azure"
}

output "permutation" {
  description = "Permutation (Terraform workspace) deployed by this state."
  value       = local.permutation
}

output "api_endpoints" {
  description = "Public base URL per deployed API runtime."
  value       = local.api_base_urls
}

output "permutations" {
  description = "Every deployed cloud x API runtime x database engine permutation with ready-to-curl URLs."
  value = merge([
    for runtime, base_url in local.api_base_urls : {
      for engine in var.database_engines : "azure-${runtime}-${engine}" => {
        cloud        = "azure"
        api_runtime  = runtime
        db_engine    = engine
        base_url     = base_url
        health_url   = "${base_url}${local.api_runtimes[runtime].health_path}/${engine}"
        resource_url = "${base_url}/api/${engine}${module.catalog.sample_resource_path}"
        graphql_url  = "${base_url}/graphql"
      }
    }
  ]...)
}

output "databases" {
  description = "Database endpoints per engine (credentials stay in state / Container App secrets)."
  value = {
    for engine, db in local.database_endpoints : engine => {
      host          = db.host
      port          = db.port
      database_name = local.database_engines[engine].database_name
      username      = var.db_admin_username
    }
  }
}

output "container_images" {
  description = "Image reference per API runtime pushed to Azure Container Registry."
  value       = { for runtime, image in module.api_image : runtime => image.image_reference }
}

output "resource_group_name" {
  description = "Resource group holding every resource of this permutation."
  value       = azurerm_resource_group.this.name
}
