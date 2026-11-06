# ---------------------------------------------------------------------------
# Permutation selectors (shared with the Azure stack, see crm-infra/permutations)
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
  description = "Database engines to deploy: any of ms (SQL Server), pg (PostgreSQL)."
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
# Target environment (LocalStack emulator vs. real AWS)
# ---------------------------------------------------------------------------
variable "localstack_enabled" {
  description = "Target the LocalStack AWS emulator. Set to false to deploy the identical stack to a real AWS account."
  type        = bool
  default     = true
}

variable "localstack_endpoint" {
  description = "LocalStack AWS gateway endpoint as seen from the host."
  type        = string
  default     = "http://localhost:4566"
}

variable "localstack_gateway_port" {
  description = "LocalStack gateway port that fronts emulated load balancers (used to build the public API URLs)."
  type        = number
  default     = 4566
}

variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short project name used as resource name prefix."
  type        = string
  default     = "crm"
}

# ---------------------------------------------------------------------------
# Sizing & platform
# ---------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "CIDR block of the VPC."
  type        = string
  default     = "10.40.0.0/16"
}

variable "image_platform" {
  description = "Platform of the API images: linux/arm64 (Apple Silicon / Graviton) or linux/amd64."
  type        = string
  default     = "linux/arm64"

  validation {
    condition     = contains(["linux/arm64", "linux/amd64"], var.image_platform)
    error_message = "image_platform must be linux/arm64 or linux/amd64."
  }
}

variable "api_task_cpu" {
  description = "Fargate CPU units per API task."
  type        = number
  default     = 512
}

variable "api_task_memory" {
  description = "Fargate memory (MiB) per API task."
  type        = number
  default     = 1024
}

variable "api_desired_count" {
  description = "Number of tasks per API service."
  type        = number
  default     = 1
}

variable "db_instance_class" {
  description = "RDS instance class for both engines."
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage_gb" {
  description = "RDS allocated storage (GiB)."
  type        = number
  default     = 20
}

variable "db_backup_retention_days" {
  description = "RDS automated backup retention (days)."
  type        = number
  default     = 0
}

variable "postgres_engine_version" {
  description = "RDS PostgreSQL engine version."
  type        = string
  default     = "16"
}

variable "db_admin_username" {
  description = "Master user name of both RDS instances."
  type        = string
  default     = "crmadmin"
}

variable "database_admin_cidrs" {
  description = "CIDRs allowed to reach the databases directly (host-side schema migrator). Restrict to your IP on real AWS."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention for API services."
  type        = number
  default     = 7
}
