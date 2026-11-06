# ============================================================================
# Offline permutation tests for the Azure stack (no LocalStack required).
# Providers are mocked and the host-side schema migrator is overridden, so the
# suite verifies wiring, naming and the runtime configuration contract only.
#   terraform -chdir=crm-infra/terraform/azure test
# ============================================================================

mock_provider "azurerm" {
  mock_resource "azurerm_resource_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-crm"
    }
  }

  mock_resource "azurerm_postgresql_flexible_server" {
    defaults = {
      id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-crm/providers/Microsoft.DBforPostgreSQL/flexibleServers/crm-pg"
      fqdn = "crm-pg.postgresql.azure.localhost.localstack.cloud:4611"
    }
  }

  mock_resource "azurerm_mssql_server" {
    defaults = {
      id                          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-crm/providers/Microsoft.Sql/servers/crm-ms"
      fully_qualified_domain_name = "crm-ms.database.azure.localhost.localstack.cloud"
    }
  }

  mock_resource "azurerm_container_registry" {
    defaults = {
      login_server   = "crmacr.azurecr.azure.localhost.localstack.cloud:4567"
      admin_username = "crmacr"
      admin_password = "test"
    }
  }

  mock_resource "azurerm_container_app_environment" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-crm/providers/Microsoft.App/managedEnvironments/cae-crm"
    }
  }

  mock_resource "azurerm_container_app" {
    defaults = {
      ingress = {
        fqdn = "crm-app.aca.azure.localhost.localstack.cloud"
      }
    }
  }
}

mock_provider "docker" {}

override_module {
  target = module.database_schema
  outputs = {
    deployment_id = "mocked"
  }
}

run "all_permutations" {
  command = apply

  assert {
    condition     = toset(keys(output.permutations)) == toset(["azure-csharp-ms", "azure-csharp-pg", "azure-kotlin-ms", "azure-kotlin-pg"])
    error_message = "The default permutation must expose all four Azure permutations."
  }

  assert {
    condition     = output.permutations["azure-csharp-ms"].health_url == "https://crm-app.aca.azure.localhost.localstack.cloud:4567/health/ms"
    error_message = "LocalStack Container App URLs must be routed through the LocalStack gateway port."
  }

  assert {
    condition     = output.databases["pg"].host == "crm-pg.postgresql.azure.localhost.localstack.cloud" && output.databases["pg"].port == 4611
    error_message = "The emulator port embedded in the PostgreSQL FQDN must be split into host and port."
  }

  assert {
    condition     = output.databases["ms"].port == 1433
    error_message = "SQL Server must fall back to the default TDS port when the FQDN carries none."
  }

  assert {
    condition     = startswith(module.runtime_config.secrets["kotlin"]["CONNECTIONSTRINGS_CRMDATABASEPG"], "Host=crm-pg.postgresql.azure.localhost.localstack.cloud;Port=4611;Database=CRMDatabase;")
    error_message = "Kotlin must connect to the Azure PostgreSQL host and emulator port."
  }

  assert {
    condition     = strcontains(module.runtime_config.secrets["csharp"]["ConnectionStrings__CRMDatabasePG"], "SSL Mode=Require;")
    error_message = "C# must connect to Azure PostgreSQL with TLS required."
  }

  assert {
    condition     = startswith(output.container_images["kotlin"], "crmacr.azurecr.azure.localhost.localstack.cloud:4567/crm-all-kotlin:")
    error_message = "API images must be pushed to the Azure Container Registry."
  }
}

run "kotlin_on_sql_server_only" {
  command = apply

  variables {
    api_runtimes     = ["kotlin"]
    database_engines = ["ms"]
  }

  assert {
    condition     = keys(output.permutations) == ["azure-kotlin-ms"]
    error_message = "Only the azure-kotlin-ms permutation must be deployed."
  }

  assert {
    condition     = length(module.postgresql) == 0 && keys(module.mssql) == ["ms"]
    error_message = "Only the Azure SQL Database must be provisioned."
  }

  assert {
    condition     = module.runtime_config.secret_names["kotlin"] == ["CONNECTIONSTRINGS_CRMDATABASEMS"]
    error_message = "Kotlin must only receive the SQL Server connection string."
  }
}

run "csharp_on_postgres_only" {
  command = apply

  variables {
    api_runtimes     = ["csharp"]
    database_engines = ["pg"]
  }

  assert {
    condition     = keys(output.permutations) == ["azure-csharp-pg"]
    error_message = "Only the azure-csharp-pg permutation must be deployed."
  }

  assert {
    condition     = length(module.mssql) == 0 && keys(module.api_app) == ["csharp"]
    error_message = "Only PostgreSQL and the C# Container App must be provisioned."
  }
}

run "rejects_unknown_engine" {
  command = plan

  variables {
    database_engines = ["oracle"]
  }

  expect_failures = [var.database_engines]
}
