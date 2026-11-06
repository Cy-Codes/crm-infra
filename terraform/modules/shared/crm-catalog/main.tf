# ============================================================================
# CRM Workload Catalog (pure, cloud-agnostic)
# Single source of truth describing every deployable API runtime and database
# engine. Both the AWS and Azure stacks consume this catalog, which is what
# makes every permutation portable between providers.
# ============================================================================

locals {
  container_http_port = 8080
  health_path         = "/health"

  api_runtimes = {
    csharp = {
      display_name   = "CrmApiCSharp (.NET 10 / C# 13)"
      source_dir     = "${var.repository_root}/CrmApiCSharp"
      container_port = local.container_http_port
      health_path    = local.health_path
    }
    kotlin = {
      display_name   = "CrmApiKotlinSpringBoot (Kotlin 2.x / Spring Boot)"
      source_dir     = "${var.repository_root}/CrmApiKotlinSpringBoot"
      container_port = local.container_http_port
      health_path    = local.health_path
    }
  }

  database_engines = {
    ms = {
      display_name  = "Microsoft SQL Server (state-based DACPAC)"
      source_dir    = "${var.repository_root}/CRMDatabaseMS"
      database_name = "CRMDatabaseMS"
      default_port  = 1433
      # The SQL Server base image is only published for linux/amd64
      migrator_platform = "linux/amd64"
    }
    pg = {
      display_name      = "PostgreSQL 16 (migration-based Flyway scripts)"
      source_dir        = "${var.repository_root}/CRMDatabasePG"
      database_name     = "CRMDatabase"
      default_port      = 5432
      migrator_platform = null
    }
  }

  sample_resource_path = "/v1/salesforce/accounts"
}
