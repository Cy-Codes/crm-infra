output "load_balancer_dns_name" {
  description = "DNS name of the service load balancer."
  value       = aws_lb.this.dns_name
}

output "service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.this.name
}

output "log_group_name" {
  description = "CloudWatch Logs group of the service."
  value       = aws_cloudwatch_log_group.this.name
}
