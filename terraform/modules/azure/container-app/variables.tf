variable "name" {
  description = "Container App name (lowercase alphanumerics and '-', max 32 characters)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,30}[a-z0-9]$", var.name))
    error_message = "name must be 2-32 lowercase alphanumerics or '-', starting with a letter."
  }
}

variable "resource_group_name" {
  description = "Resource group of the app."
  type        = string
}

variable "container_app_environment_id" {
  description = "Container Apps environment ID."
  type        = string
}

variable "image" {
  description = "Container image reference."
  type        = string
}

variable "registry" {
  description = "Container registry the image is pulled from."
  type = object({
    server   = string
    username = string
    password = string
  })
}

variable "container_port" {
  description = "Port the container listens on."
  type        = number
}

variable "health_path" {
  description = "HTTP health probe path."
  type        = string
}

variable "environment" {
  description = "Plain environment variables."
  type        = map(string)
  default     = {}
}

variable "secret_names" {
  description = "Names of the secret environment variables (keys of `secrets`)."
  type        = list(string)
  default     = []
}

variable "secrets" {
  description = "Secret environment variables, stored as Container App secrets."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "cpu" {
  description = "vCPU per replica (e.g. 0.5)."
  type        = number
}

variable "memory" {
  description = "Memory per replica (e.g. 1Gi); must pair with the selected CPU."
  type        = string
}

variable "min_replicas" {
  description = "Minimum replica count."
  type        = number
}

variable "max_replicas" {
  description = "Maximum replica count."
  type        = number
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
