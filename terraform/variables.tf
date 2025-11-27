variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-west-2"
}

variable "environment" {
  type        = string
  description = "Environment name (dev/prod)"
  default     = "prod"
}

variable "ecs_cluster_name" {
  type        = string
  description = "Name of the ECS cluster"
  default     = "ds2-prod-ecs-cluster"
}

variable "image_tag" {
  type        = string
  description = "Docker image tag to deploy"
  default     = "latest"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where resources will be deployed"
  default     = "vpc-04f4c4cf527f99b9a"
}

# Variables for importing existing VPC resources
# These IDs should be retrieved from AWS before running terraform import

variable "default_security_group_id" {
  type        = string
  description = "ID of the default security group in the VPC (for import)"
  default     = ""
}

variable "main_route_table_id" {
  type        = string
  description = "ID of the main route table in the VPC (for import)"
  default     = ""
}

variable "default_nacl_id" {
  type        = string
  description = "ID of the default network ACL in the VPC (for import)"
  default     = ""
}
