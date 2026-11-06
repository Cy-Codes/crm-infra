variable "name_prefix" {
  description = "Prefix applied to every resource name."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC."
  type        = string
}

variable "availability_zone_count" {
  description = "Number of availability zones (and public subnets) to span; RDS and ALB require at least two."
  type        = number
  default     = 2
}

variable "api_container_port" {
  description = "Container port exposed by the API tasks."
  type        = number
}

variable "database_ports" {
  description = "Database listener ports allowed into the database security group."
  type        = list(number)
}

variable "database_admin_cidrs" {
  description = "CIDRs allowed to reach the databases directly (schema migrator / DBA access). Tighten for real AWS accounts."
  type        = list(string)
}
