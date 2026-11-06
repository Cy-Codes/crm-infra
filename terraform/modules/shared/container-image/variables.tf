variable "repository" {
  description = "Fully qualified image repository without tag (e.g. <registry>/<name>, or a bare local name when not pushing)."
  type        = string
}

variable "context_dir" {
  description = "Absolute path of the Docker build context (the sub-repository root)."
  type        = string
}

variable "dockerfile" {
  description = "Dockerfile path relative to the build context."
  type        = string
  default     = "Dockerfile"
}

variable "source_globs" {
  description = "Globs (relative to the context) whose file contents determine the image tag."
  type        = list(string)
  default     = ["**"]
}

variable "source_exclude_regex" {
  description = "Regular expression of context-relative paths ignored when hashing (local build output, caches, VCS metadata)."
  type        = string
  default     = "(^|/)(bin|obj|build|out|\\.gradle|\\.kotlin|\\.idea|\\.git|node_modules)(/|$)"
}

variable "tag_length" {
  description = "Number of content-hash characters used as the image tag."
  type        = number
  default     = 12
}

variable "platform" {
  description = "Target platform of the image (e.g. linux/arm64, linux/amd64). Null builds for the Docker daemon's native platform."
  type        = string
  default     = null
}

variable "labels" {
  description = "OCI labels applied to the built image."
  type        = map(string)
  default     = {}
}

variable "push_enabled" {
  description = "Whether to push the image to `registry`. Disabled for local-only images such as schema migrators."
  type        = bool
  default     = false
}

variable "registry" {
  description = "Registry address and credentials used when `push_enabled` is true."
  type = object({
    address  = string
    username = string
    password = string
  })
  default = null
}
