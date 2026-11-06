variable "databases" {
  description = "Provisioned database endpoints keyed by provider code (ms | pg). Engines that are not deployed are simply omitted."
  type = map(object({
    host          = string
    port          = number
    database_name = string
    username      = string
    password      = string
    ssl_mode      = string
  }))

  validation {
    condition     = alltrue([for engine, db in var.databases : contains(["ms", "pg"], engine) && contains(["disable", "prefer", "require"], db.ssl_mode)])
    error_message = "Database keys must be 'ms' or 'pg' and ssl_mode must be one of: disable, prefer, require."
  }
}
