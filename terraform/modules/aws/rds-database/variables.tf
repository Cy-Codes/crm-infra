variable "name_prefix" {
  description = "Prefix applied to every resource name."
  type        = string
}

variable "engine" {
  description = "Database provider code: ms (SQL Server) or pg (PostgreSQL)."
  type        = string

  validation {
    condition     = contains(["ms", "pg"], var.engine)
    error_message = "engine must be 'ms' or 'pg'."
  }
}

variable "database_name" {
  description = "Application database name (created by RDS for PostgreSQL, by the DACPAC publish for SQL Server)."
  type        = string
}

variable "postgres_engine_version" {
  description = "PostgreSQL engine version."
  type        = string
}

variable "sqlserver_engine_version" {
  description = "SQL Server engine version. Null selects the RDS default."
  type        = string
  default     = null
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
}

variable "allocated_storage_gb" {
  description = "Allocated storage in GiB."
  type        = number
}

variable "backup_retention_days" {
  description = "Automated backup retention in days (0 disables backups)."
  type        = number
}

variable "username" {
  description = "Master user name."
  type        = string
}

variable "password" {
  description = "Master user password."
  type        = string
  sensitive   = true
}

variable "subnet_ids" {
  description = "Subnets of the DB subnet group."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups attached to the instance."
  type        = list(string)
}

variable "publicly_accessible" {
  description = "Expose the instance on a public endpoint (required for the host-side schema migrator)."
  type        = bool
}

variable "skip_final_snapshot" {
  description = "Skip final DB snapshot on deletion (true for local emulation/ephemeral environments)."
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Enable deletion protection on the RDS instance."
  type        = bool
  default     = false
}
