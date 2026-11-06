variable "address" {
  description = "Endpoint address in the form host or host:port."
  type        = string
}

variable "default_port" {
  description = "Port used when the address does not include one."
  type        = number
}
