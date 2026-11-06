# ----------------------------------------------------------------------------
# AzureRM provider: LocalStack for Azure by default (via metadata_host), real
# Azure when localstack_enabled=false. Credentials come from the standard
# ARM_CLIENT_ID / ARM_CLIENT_SECRET / ARM_TENANT_ID / ARM_SUBSCRIPTION_ID
# environment variables (crm-infra/.env); the emulator accepts any service principal.
# ----------------------------------------------------------------------------
provider "azurerm" {
  features {}

  metadata_host                   = var.localstack_enabled ? var.localstack_metadata_host : null
  resource_provider_registrations = var.localstack_enabled ? "none" : "core"
}

# Local Docker daemon (honours DOCKER_HOST) used to build images and run schema migrators.
provider "docker" {}
