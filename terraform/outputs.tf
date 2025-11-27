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

# VPC-related outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = data.aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = data.aws_vpc.main.cidr_block
}

output "default_security_group_id" {
  description = "ID of the default security group"
  value       = aws_default_security_group.default.id
}

output "main_route_table_id" {
  description = "ID of the main route table"
  value       = aws_default_route_table.main.id
}

output "default_nacl_id" {
  description = "ID of the default network ACL"
  value       = aws_default_network_acl.default.id
}
