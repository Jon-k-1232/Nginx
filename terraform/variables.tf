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
  description = "Docker image tag to deploy (pinned to an immutable tag so ECS pulls deterministically)"
  default     = "tls-efs-20260611-233558"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where resources will be deployed"
  default     = "vpc-04f4c4cf527f99b9a"
}
