variable "server_name" {
  description = "Globally unique logical server name."
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

variable "server_version" {
  description = "Logical server version."
  type        = string
}

variable "minimum_tls_version" {
  description = "Minimum TLS version accepted by the server."
  type        = string
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

variable "sku_name" {
  description = "Database SKU (e.g. S0, GP_S_Gen5_1)."
  type        = string
}

variable "max_size_gb" {
  description = "Maximum database size in GiB."
  type        = number
}

variable "default_port" {
  description = "TDS port used when the server FQDN does not carry one."
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
