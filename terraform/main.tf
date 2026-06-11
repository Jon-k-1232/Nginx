locals {
  name_prefix = "ds2-${var.environment}"
}

# Data source for existing ECS cluster
data "aws_ecs_cluster" "main" {
  cluster_name = var.ecs_cluster_name
}

# Data source for existing IAM roles (created by backend)
data "aws_iam_role" "ecs_execution" {
  name = "${local.name_prefix}-ecs-execution-role"
}

data "aws_iam_role" "ecs_task" {
  name = "${local.name_prefix}-ecs-task-role"
}

# Data source for ECR repository
data "aws_ecr_repository" "nginx" {
  name = "${local.name_prefix}-nginx"
}

# CloudWatch Log Group for Nginx
resource "aws_cloudwatch_log_group" "nginx" {
  name              = "/aws/ecs/${local.name_prefix}-nginx"
  retention_in_days = 14

  tags = {
    Name        = "${local.name_prefix}-nginx-logs"
    Environment = var.environment
  }
}

# ECS Task Definition for Nginx
resource "aws_ecs_task_definition" "nginx" {
  family                = "${local.name_prefix}-nginx"
  network_mode          = "host"
  execution_role_arn    = data.aws_iam_role.ecs_execution.arn
  task_role_arn         = data.aws_iam_role.ecs_task.arn

  # Shared EFS holding the auto-renewed Let's Encrypt cert (written by the
  # certbot ECS task). Mounted read-only; nginx reads the cert from here.
  volume {
    name = "letsencrypt"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.letsencrypt.id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.letsencrypt.id
      }
    }
  }

  container_definitions = jsonencode([
    {
      name      = "nginx"
      image     = "${data.aws_ecr_repository.nginx.repository_url}:${var.image_tag}"
      essential = true
      # Right-sized from 256: nginx uses ~30-50MB; this frees headroom on the
      # single instance for the scheduled certbot task.
      memory = 128

      # Host network mode doesn't use port mappings - container directly uses host ports
      # portMappings not needed in host mode

      mountPoints = [
        { sourceVolume = "letsencrypt", containerPath = "/etc/letsencrypt", readOnly = true }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.nginx.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "nginx"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }
    }
  ])

  tags = {
    Name        = "${local.name_prefix}-nginx-task"
    Environment = var.environment
  }
}

# ECS Service for Nginx
resource "aws_ecs_service" "nginx" {
  name            = "${local.name_prefix}-nginx-service"
  cluster         = data.aws_ecs_cluster.main.arn
  task_definition = aws_ecs_task_definition.nginx.arn
  desired_count   = 1

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  capacity_provider_strategy {
    capacity_provider = "${local.name_prefix}-capacity-provider"
    weight            = 1
    base              = 0
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = {
    Name        = "${local.name_prefix}-nginx-service"
    Environment = var.environment
  }
}

# CloudWatch Alarm for Nginx Memory
resource "aws_cloudwatch_metric_alarm" "nginx_memory_high" {
  alarm_name          = "${local.name_prefix}-nginx-memory-high"
  alarm_description   = "Alert when nginx memory usage is high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    ClusterName = data.aws_ecs_cluster.main.cluster_name
    ServiceName = aws_ecs_service.nginx.name
  }

  tags = {
    Name        = "${local.name_prefix}-nginx-memory-alarm"
    Environment = var.environment
  }
}
