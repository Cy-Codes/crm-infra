# ============================================================================
# CRM Reference Architecture - Azure Stack
#   ACR (images) -> Azure SQL Database / PostgreSQL Flexible Server
#   -> schema migrators -> Azure Container Apps with external ingress
# Every cloud-specific resource lives in modules/azure; everything that
# defines *what* is deployed lives in modules/shared and is identical on AWS.
# ============================================================================

locals {
  repository_root = abspath("${path.root}/../../..")
  permutation     = terraform.workspace == "default" ? "all" : terraform.workspace
  name_prefix     = "${var.project_name}-${local.permutation}"
  compact_prefix  = replace(local.name_prefix, "-", "")

  tags = {
    project     = var.project_name
    permutation = local.permutation
    managed-by  = "terraform"
    emulated    = tostring(var.localstack_enabled)
  }

  loopback_hosts         = ["localhost", "127.0.0.1"]
  docker_host_gateway    = "host.docker.internal"
  postgres_ssl_mode      = "require"
  minimum_tls_version    = "1.2"
  suffix_length          = 6
  password_length        = 24
  password_special_chars = "!#%*-_"

  api_runtimes     = { for runtime in var.api_runtimes : runtime => module.catalog.api_runtimes[runtime] }
  database_engines = { for engine in var.database_engines : engine => module.catalog.database_engines[engine] }

  # The managed database offering differs per engine on Azure, so each engine has its own module.
  postgresql_engines = { for engine, db in local.database_engines : engine => db if engine == "pg" }
  mssql_engines      = { for engine, db in local.database_engines : engine => db if engine == "ms" }

  database_endpoints = merge(
    { for engine, db in module.postgresql : engine => { host = db.host, port = db.port } },
    { for engine, db in module.mssql : engine => { host = db.host, port = db.port } },
  )

  databases = {
    for engine, endpoint in local.database_endpoints : engine => {
      host          = endpoint.host
      port          = endpoint.port
      database_name = local.database_engines[engine].database_name
      username      = var.db_admin_username
      password      = random_password.database[engine].result
      ssl_mode      = local.postgres_ssl_mode
    }
  }

  registry = {
    server   = azurerm_container_registry.this.login_server
    username = azurerm_container_registry.this.admin_username
    password = azurerm_container_registry.this.admin_password
  }

  api_base_urls = {
    for runtime, app in module.api_app : runtime => (
      var.localstack_enabled
      ? "https://${app.fqdn}:${var.localstack_gateway_port}"
      : "https://${app.fqdn}"
    )
  }
}

module "catalog" {
  source = "../modules/shared/crm-catalog"

  repository_root = local.repository_root
}

resource "random_string" "suffix" {
  length  = local.suffix_length
  upper   = false
  special = false
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.tags
}

# ---------------------------------------------------------------------------
# Data tier: managed databases + schema deployment
# ---------------------------------------------------------------------------
resource "random_password" "database" {
  for_each = local.database_engines

  length           = local.password_length
  special          = true
  override_special = local.password_special_chars
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
}

module "postgresql" {
  source   = "../modules/azure/postgresql-flexible"
  for_each = local.postgresql_engines

  server_name            = "${local.name_prefix}-${each.key}-${random_string.suffix.result}"
  resource_group_name    = azurerm_resource_group.this.name
  location               = azurerm_resource_group.this.location
  postgres_version       = var.postgres_version
  sku_name               = var.postgres_sku_name
  storage_mb             = var.postgres_storage_mb
  backup_retention_days  = var.db_backup_retention_days
  administrator_login    = var.db_admin_username
  administrator_password = random_password.database[each.key].result
  database_name          = each.value.database_name
  default_port           = each.value.default_port
  firewall_rules         = var.database_firewall_rules
  tags                   = local.tags
}

module "mssql" {
  source   = "../modules/azure/mssql-database"
  for_each = local.mssql_engines

  server_name            = "${local.name_prefix}-${each.key}-${random_string.suffix.result}"
  resource_group_name    = azurerm_resource_group.this.name
  location               = azurerm_resource_group.this.location
  server_version         = var.mssql_server_version
  minimum_tls_version    = local.minimum_tls_version
  administrator_login    = var.db_admin_username
  administrator_password = random_password.database[each.key].result
  database_name          = each.value.database_name
  sku_name               = var.mssql_sku_name
  max_size_gb            = var.mssql_max_size_gb
  default_port           = each.value.default_port
  firewall_rules         = var.database_firewall_rules
  tags                   = local.tags
}

module "database_schema" {
  source   = "../modules/shared/database-schema"
  for_each = local.database_engines

  engine                      = each.key
  source_dir                  = each.value.source_dir
  image_repository            = "${local.name_prefix}-${each.key}-migrator"
  platform                    = each.value.migrator_platform
  host                        = var.localstack_enabled && contains(local.loopback_hosts, local.databases[each.key].host) ? local.docker_host_gateway : local.databases[each.key].host
  port                        = local.databases[each.key].port
  database_name               = local.databases[each.key].database_name
  username                    = local.databases[each.key].username
  password                    = local.databases[each.key].password
  ssl_mode                    = local.databases[each.key].ssl_mode
  seed_data                   = var.seed_data
  allow_incompatible_platform = true
  host_aliases                = var.localstack_enabled && !contains(local.loopback_hosts, local.databases[each.key].host) ? [local.databases[each.key].host] : []
}

module "runtime_config" {
  source = "../modules/shared/crm-runtime-config"

  databases = local.databases
}

# ---------------------------------------------------------------------------
# Compute tier: ACR images + Azure Container Apps
# ---------------------------------------------------------------------------
resource "azurerm_container_registry" "this" {
  name                = "${local.compact_prefix}${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "Basic"
  admin_enabled       = true
  tags                = local.tags
}

module "api_image" {
  source   = "../modules/shared/container-image"
  for_each = local.api_runtimes

  repository   = "${azurerm_container_registry.this.login_server}/${local.name_prefix}-${each.key}"
  context_dir  = each.value.source_dir
  platform     = var.image_platform
  push_enabled = true
  registry = {
    address  = local.registry.server
    username = local.registry.username
    password = local.registry.password
  }
  labels = {
    "org.opencontainers.image.title"       = each.value.display_name
    "org.opencontainers.image.description" = "CRM API (${each.key}) for permutation ${local.permutation}"
  }
}

resource "azurerm_container_app_environment" "this" {
  name                = "cae-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = local.tags
}

module "api_app" {
  source   = "../modules/azure/container-app"
  for_each = local.api_runtimes

  name                         = "${local.name_prefix}-${each.key}"
  resource_group_name          = azurerm_resource_group.this.name
  container_app_environment_id = azurerm_container_app_environment.this.id
  image                        = module.api_image[each.key].image_reference
  registry                     = local.registry
  container_port               = each.value.container_port
  health_path                  = each.value.health_path
  environment                  = module.runtime_config.environment[each.key]
  secret_names                 = module.runtime_config.secret_names[each.key]
  secrets                      = module.runtime_config.secrets[each.key]
  cpu                          = var.api_cpu
  memory                       = var.api_memory
  min_replicas                 = var.api_min_replicas
  max_replicas                 = var.api_max_replicas
  tags                         = local.tags

  depends_on = [module.database_schema]
}
