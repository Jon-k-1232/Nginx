output "nginx_service_name" {
  description = "Name of the nginx ECS service"
  value       = aws_ecs_service.nginx.name
}

output "nginx_task_definition_arn" {
  description = "ARN of the nginx task definition"
  value       = aws_ecs_task_definition.nginx.arn
}

output "nginx_ecr_repository_url" {
  description = "ECR repository URL for nginx"
  value       = data.aws_ecr_repository.nginx.repository_url
}

output "nginx_log_group" {
  description = "CloudWatch log group for nginx"
  value       = aws_cloudwatch_log_group.nginx.name
}
