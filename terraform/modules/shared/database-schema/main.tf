# ============================================================================
# Database Schema Deployment (cloud-agnostic)
# Re-uses each database sub-repository image as a one-shot migrator that is
# pointed at a managed database endpoint (Amazon RDS, Azure SQL Database,
# Azure Database for PostgreSQL, ...):
#   ms -> CRMDatabaseMS/publish.sh   (state-based DACPAC publish + seed)
#   pg -> CRMDatabasePG/entrypoint.sh (versioned V1..Vn migrations + seed)
# The migrator runs on the local Docker daemon, so the identical process
# works against LocalStack emulators and real cloud accounts.
# ============================================================================

terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

locals {
  runners = {
    ms = {
      entrypoint = "/app/publish.sh"
      environment = {
        DB_HOST                     = var.host
        DB_PORT                     = tostring(var.port)
        DB_NAME                     = var.database_name
        DB_USER                     = var.username
        DB_PASSWORD                 = var.password
        SEED_DATA                   = var.seed_data
        ALLOW_INCOMPATIBLE_PLATFORM = var.allow_incompatible_platform ? "True" : "False"
      }
    }
    pg = {
      entrypoint = "/docker-entrypoint-initdb.d/99_crm_init.sh"
      environment = {
        PGHOST            = var.host
        PGPORT            = tostring(var.port)
        PGSSLMODE         = var.ssl_mode
        POSTGRES_DB       = var.database_name
        POSTGRES_USER     = var.username
        POSTGRES_PASSWORD = var.password
        SEED_DATA         = var.seed_data
      }
    }
  }

  runner         = local.runners[var.engine]
  add_host_flags = join(" ", [for host in var.host_aliases : "--add-host=${host}:host-gateway"])
  env_flags      = join(" ", [for name in sort(keys(local.runner.environment)) : "--env ${name}"])
  migrator_command = join(" ", compact([
    "docker run --rm",
    local.add_host_flags,
    local.env_flags,
    var.platform == null ? "" : "--platform=${var.platform}",
    "--entrypoint ${local.runner.entrypoint}",
    module.migrator_image.image_reference,
  ]))
}

module "migrator_image" {
  source = "../container-image"

  repository   = var.image_repository
  context_dir  = var.source_dir
  platform     = var.platform
  push_enabled = false
  labels = {
    "org.opencontainers.image.title" = "${var.image_repository} schema migrator"
  }
}

# Re-runs whenever the schema source, the target endpoint or the seed mode changes.
resource "terraform_data" "schema" {
  triggers_replace = {
    image_id      = module.migrator_image.image_id
    host          = var.host
    port          = var.port
    database_name = var.database_name
    seed_data     = var.seed_data
  }

  # Credentials travel via environment variables (never the command line). They are
  # unwrapped from their sensitive marking only so Terraform keeps streaming the
  # migrator logs instead of suppressing the whole provisioner output.
  provisioner "local-exec" {
    command     = local.migrator_command
    environment = { for name, value in local.runner.environment : name => nonsensitive(sensitive(value)) }
  }
}
