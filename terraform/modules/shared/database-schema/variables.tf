variable "engine" {
  description = "Database provider code: ms (SQL Server DACPAC) or pg (PostgreSQL migrations)."
  type        = string

  validation {
    condition     = contains(["ms", "pg"], var.engine)
    error_message = "engine must be 'ms' or 'pg'."
  }
}

variable "source_dir" {
  description = "Absolute path of the database sub-repository (Docker build context of the migrator image)."
  type        = string
}

variable "image_repository" {
  description = "Local image name used for the migrator image."
  type        = string
}

variable "platform" {
  description = "Platform of the migrator image (SQL Server images are linux/amd64 only). Null uses the daemon's native platform."
  type        = string
  default     = null
}

variable "host" {
  description = "Database endpoint host name."
  type        = string
}

variable "port" {
  description = "Database endpoint port."
  type        = number
}

variable "database_name" {
  description = "Target database name."
  type        = string
}

variable "username" {
  description = "Administrator login used to deploy the schema."
  type        = string
}

variable "password" {
  description = "Administrator password used to deploy the schema."
  type        = string
  sensitive   = true
}

variable "ssl_mode" {
  description = "libpq SSL mode for PostgreSQL targets (disable | prefer | require)."
  type        = string
  default     = "prefer"
}

variable "seed_data" {
  description = "Seed mode passed to the migrator: none | standard | heavy."
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["none", "standard", "heavy"], var.seed_data)
    error_message = "seed_data must be one of: none, standard, heavy."
  }
}

variable "allow_incompatible_platform" {
  description = "Allow publishing the SQL Server DACPAC to a different target platform (required for Azure SQL Database)."
  type        = bool
  default     = false
}

variable "host_aliases" {
  description = "Host names that the migrator container resolves to the Docker host gateway (needed for LocalStack's *.localhost.localstack.cloud endpoints)."
  type        = list(string)
  default     = []
}
