# ============================================================================
# Azure Container App with external HTTPS ingress
# Azure counterpart of the ECS Fargate service + ALB in the AWS stack. Plain
# settings become container environment variables; secret settings are stored
# as Container App secrets and referenced through `secret_name`.
# ============================================================================

locals {
  registry_password_secret = "registry-password"
  probe_transport          = "HTTP"
  full_traffic_percentage  = 100

  # Container App secret names allow lowercase alphanumerics and '-' only.
  secret_refs = { for name in var.secret_names : name => lower(replace(name, "_", "-")) }
}

resource "azurerm_container_app" "this" {
  name                         = var.name
  resource_group_name          = var.resource_group_name
  container_app_environment_id = var.container_app_environment_id
  revision_mode                = "Single"
  tags                         = var.tags

  registry {
    server               = var.registry.server
    username             = var.registry.username
    password_secret_name = local.registry_password_secret
  }

  secret {
    name  = local.registry_password_secret
    value = var.registry.password
  }

  dynamic "secret" {
    for_each = local.secret_refs
    content {
      name  = secret.value
      value = var.secrets[secret.key]
    }
  }

  ingress {
    external_enabled = true
    target_port      = var.container_port

    traffic_weight {
      latest_revision = true
      percentage      = local.full_traffic_percentage
    }
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = var.name
      image  = var.image
      cpu    = var.cpu
      memory = var.memory

      dynamic "env" {
        for_each = var.environment
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = local.secret_refs
        content {
          name        = env.key
          secret_name = env.value
        }
      }

      liveness_probe {
        transport = local.probe_transport
        port      = var.container_port
        path      = var.health_path
      }

      readiness_probe {
        transport = local.probe_transport
        port      = var.container_port
        path      = var.health_path
      }
    }
  }
}
