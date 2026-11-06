variable "server_name" {
  description = "Globally unique server name."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group of the server."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "postgres_version" {
  description = "PostgreSQL major version."
  type        = string
}

variable "sku_name" {
  description = "Compute SKU (e.g. B_Standard_B1ms)."
  type        = string
}

variable "storage_mb" {
  description = "Storage size in MiB."
  type        = number
}

variable "backup_retention_days" {
  description = "Backup retention in days."
  type        = number
}

variable "administrator_login" {
  description = "Administrator login."
  type        = string
}

variable "administrator_password" {
  description = "Administrator password."
  type        = string
  sensitive   = true
}

variable "database_name" {
  description = "Application database name."
  type        = string
}

variable "default_port" {
  description = "PostgreSQL port used when the server FQDN does not carry one."
  type        = number
}

variable "firewall_rules" {
  description = "Firewall rules keyed by rule name."
  type = map(object({
    start_ip_address = string
    end_ip_address   = string
  }))
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
