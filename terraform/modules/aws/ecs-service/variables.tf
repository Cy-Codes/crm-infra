variable "name" {
  description = "Service name (also used for the task family, load balancer and target group; max 32 characters)."
  type        = string

  validation {
    condition     = length(var.name) <= 32
    error_message = "name must be at most 32 characters (ALB / target group limit)."
  }
}

variable "region" {
  description = "AWS region (used by the awslogs driver)."
  type        = string
}

variable "cluster_id" {
  description = "ECS cluster ID."
  type        = string
}

variable "image" {
  description = "Container image reference."
  type        = string
}

variable "container_port" {
  description = "Port the container listens on."
  type        = number
}

variable "health_path" {
  description = "HTTP health check path."
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
  description = "Secret environment variables, stored in AWS Secrets Manager."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "cpu" {
  description = "Fargate task CPU units."
  type        = number
}

variable "memory" {
  description = "Fargate task memory (MiB)."
  type        = number
}

variable "cpu_architecture" {
  description = "Task CPU architecture: ARM64 or X86_64 (must match the image platform)."
  type        = string
}

variable "desired_count" {
  description = "Number of running tasks."
  type        = number
}

variable "vpc_id" {
  description = "VPC of the target group."
  type        = string
}

variable "subnet_ids" {
  description = "Subnets for the load balancer and tasks."
  type        = list(string)
}

variable "load_balancer_security_group_id" {
  description = "Security group of the load balancer."
  type        = string
}

variable "api_security_group_id" {
  description = "Security group of the tasks."
  type        = string
}

variable "listener_port" {
  description = "Public HTTP listener port of the load balancer."
  type        = number
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days."
  type        = number
}
