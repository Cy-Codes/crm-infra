output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs (one per availability zone)."
  value       = aws_subnet.public[*].id
}

output "load_balancer_security_group_id" {
  description = "Security group of the API load balancers."
  value       = aws_security_group.load_balancer.id
}

output "api_security_group_id" {
  description = "Security group of the API tasks."
  value       = aws_security_group.api.id
}

output "database_security_group_id" {
  description = "Security group of the databases."
  value       = aws_security_group.database.id
}

output "http_listener_port" {
  description = "Port of the public HTTP listeners."
  value       = local.http_listener_port
}

output "https_listener_port" {
  description = "Port of the public HTTPS listeners."
  value       = local.https_listener_port
}
