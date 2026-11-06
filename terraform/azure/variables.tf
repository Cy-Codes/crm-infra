# ---------------------------------------------------------------------------
# Permutation selectors (shared with the AWS stack, see crm-infra/permutations)
# ---------------------------------------------------------------------------
variable "api_runtimes" {
  description = "API runtimes to deploy: any of csharp, kotlin."
  type        = set(string)
  default     = ["csharp", "kotlin"]

  validation {
    condition     = length(var.api_runtimes) > 0 && alltrue([for runtime in var.api_runtimes : contains(["csharp", "kotlin"], runtime)])
    error_message = "api_runtimes must be a non-empty subset of [csharp, kotlin]."
  }
}

variable "database_engines" {
  description = "Database engines to deploy: any of ms (Azure SQL Database), pg (Azure Database for PostgreSQL)."
  type        = set(string)
  default     = ["ms", "pg"]

  validation {
    condition     = length(var.database_engines) > 0 && alltrue([for engine in var.database_engines : contains(["ms", "pg"], engine)])
    error_message = "database_engines must be a non-empty subset of [ms, pg]."
  }
}

variable "seed_data" {
  description = "Seed mode applied after schema deployment: none | standard | heavy."
  type        = string
  default     = "standard"
}

# ---------------------------------------------------------------------------
# Target environment (LocalStack for Azure emulator vs. real Azure)
# ---------------------------------------------------------------------------
variable "localstack_enabled" {
  description = "Target the LocalStack for Azure emulator. Set to false to deploy the identical stack to a real Azure subscription."
  type        = bool
  default     = true
}

variable "localstack_metadata_host" {
  description = "Metadata host of the LocalStack for Azure emulator (host:port)."
  type        = string
  default     = "azure.localhost.localstack.cloud:4567"
}

variable "localstack_gateway_port" {
  description = "LocalStack for Azure gateway port that fronts emulated Container Apps ingress (used to build the public API URLs)."
  type        = number
  default     = 4567
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "eastus"
}

variable "project_name" {
  description = "Short project name used as resource name prefix (lowercase letters and digits)."
  type        = string
  default     = "crm"
}

# ---------------------------------------------------------------------------
# Sizing & platform
# ---------------------------------------------------------------------------
variable "image_platform" {
  description = "Platform of the API images: linux/arm64 (Apple Silicon) or linux/amd64 (required by real Azure Container Apps)."
  type        = string
  default     = "linux/arm64"

  validation {
    condition     = contains(["linux/arm64", "linux/amd64"], var.image_platform)
    error_message = "image_platform must be linux/arm64 or linux/amd64."
  }
}

variable "api_cpu" {
  description = "vCPU per Container App replica."
  type        = number
  default     = 0.5
}

variable "api_memory" {
  description = "Memory per Container App replica (must pair with api_cpu)."
  type        = string
  default     = "1Gi"
}

variable "api_min_replicas" {
  description = "Minimum replicas per Container App."
  type        = number
  default     = 1
}

variable "api_max_replicas" {
  description = "Maximum replicas per Container App."
  type        = number
  default     = 1
}

variable "db_admin_username" {
  description = "Administrator login of both database servers."
  type        = string
  default     = "crmadmin"
}

variable "postgres_version" {
  description = "Azure Database for PostgreSQL major version."
  type        = string
  default     = "16"
}

variable "postgres_sku_name" {
  description = "Azure Database for PostgreSQL compute SKU."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "postgres_storage_mb" {
  description = "Azure Database for PostgreSQL storage (MiB)."
  type        = number
  default     = 32768
}

variable "db_backup_retention_days" {
  description = "Backup retention for Azure Database for PostgreSQL (days, minimum 7)."
  type        = number
  default     = 7
}

variable "mssql_server_version" {
  description = "Azure SQL logical server version."
  type        = string
  default     = "12.0"
}

variable "mssql_sku_name" {
  description = "Azure SQL Database SKU."
  type        = string
  default     = "S0"
}

variable "mssql_max_size_gb" {
  description = "Azure SQL Database maximum size (GiB)."
  type        = number
  default     = 10
}

variable "database_firewall_rules" {
  description = "Firewall rules applied to both database servers (host-side schema migrator / DBA access). Restrict on real Azure."
  type = map(object({
    start_ip_address = string
    end_ip_address   = string
  }))
  default = {
    allow-all = {
      start_ip_address = "0.0.0.0"
      end_ip_address   = "255.255.255.255"
    }
  }
}
