# =============================================================================
# Automated TLS renewal for ds2.kimmeloffice.com
#
# A scheduled ECS task runs certbot (Let's Encrypt DNS-01 via Route 53) and
# writes the cert to a shared EFS volume. nginx mounts the same EFS read-only
# (see main.tf nginx task def) and is rolled by the renewal's deploy-hook when
# the cert actually changes.
#
# Everything in THIS file is additive — it does not alter the running nginx
# until the EFS volume is added to the nginx task def (gated cutover).
# =============================================================================

variable "ecs_instance_sg_id" {
  type        = string
  description = "Security group of the ECS EC2 instance (source for EFS NFS)"
  default     = "sg-03b76f6fddc2cb61b"
}

variable "ecs_subnet_id" {
  type        = string
  description = "Subnet of the ECS EC2 instance (EFS mount target placement)"
  default     = "subnet-0e30e764faaeca235"
}

variable "route53_zone_id" {
  type        = string
  description = "Hosted zone ID for kimmeloffice.com (DNS-01 challenge writes)"
  default     = "Z100767436N9X2SQCO829"
}

variable "cert_domain" {
  type        = string
  description = "Domain the cert is issued for"
  default     = "ds2.kimmeloffice.com"
}

variable "certbot_email" {
  type        = string
  description = "Let's Encrypt account / expiry-notice contact email"
  default     = "admin@jimkimmel.com"
}

variable "certbot_image_tag" {
  type        = string
  description = "Tag of the ds2-prod-certbot image to run"
  default     = "latest"
}

data "aws_caller_identity" "current" {}

locals {
  nginx_service_arn = "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:service/${data.aws_ecs_cluster.main.cluster_name}/${aws_ecs_service.nginx.name}"
}

# --- EFS: durable store for /etc/letsencrypt (cert + certbot state) ----------
resource "aws_efs_file_system" "letsencrypt" {
  creation_token = "${local.name_prefix}-letsencrypt"
  encrypted      = true

  tags = {
    Name        = "${local.name_prefix}-letsencrypt"
    Environment = var.environment
  }
}

resource "aws_security_group" "efs" {
  name_prefix = "${local.name_prefix}-efs-"
  vpc_id      = var.vpc_id
  description = "NFS from the ECS instance to the LetsEncrypt EFS"

  ingress {
    description     = "NFS from ECS instance"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [var.ecs_instance_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${local.name_prefix}-efs-sg"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_efs_mount_target" "letsencrypt" {
  file_system_id  = aws_efs_file_system.letsencrypt.id
  subnet_id       = var.ecs_subnet_id
  security_groups = [aws_security_group.efs.id]
}

# Access point pins the task to /letsencrypt as root — certbot needs root-owned
# 0700 dirs (it refuses world-readable account/key dirs).
resource "aws_efs_access_point" "letsencrypt" {
  file_system_id = aws_efs_file_system.letsencrypt.id

  posix_user {
    uid = 0
    gid = 0
  }

  root_directory {
    path = "/letsencrypt"
    creation_info {
      owner_uid   = 0
      owner_gid   = 0
      permissions = "0755"
    }
  }

  tags = {
    Name        = "${local.name_prefix}-letsencrypt-ap"
    Environment = var.environment
  }
}

# --- ECR repo for the certbot renewal image ---------------------------------
resource "aws_ecr_repository" "certbot" {
  name                 = "${local.name_prefix}-certbot"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${local.name_prefix}-certbot"
    Environment = var.environment
  }
}

# --- Logs -------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "certbot" {
  name              = "/aws/ecs/${local.name_prefix}-certbot"
  retention_in_days = 30

  tags = {
    Name        = "${local.name_prefix}-certbot-logs"
    Environment = var.environment
  }
}

# --- IAM: certbot task role (DNS-01 + roll nginx on renewal) ----------------
resource "aws_iam_role" "certbot_task" {
  name = "${local.name_prefix}-certbot-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "${local.name_prefix}-certbot-task-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "certbot_task" {
  name = "${local.name_prefix}-certbot-task-policy"
  role = aws_iam_role.certbot_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # certbot-dns-route53 lists zones to resolve the domain (cannot be scoped).
        Sid      = "Route53List"
        Effect   = "Allow"
        Action   = ["route53:ListHostedZones", "route53:GetChange"]
        Resource = "*"
      },
      {
        # Write the _acme-challenge TXT only in the kimmeloffice.com zone.
        Sid      = "Route53Write"
        Effect   = "Allow"
        Action   = ["route53:ChangeResourceRecordSets"]
        Resource = "arn:aws:route53:::hostedzone/${var.route53_zone_id}"
      },
      {
        # Roll nginx to pick up a renewed cert (deploy-hook).
        Sid      = "RollNginx"
        Effect   = "Allow"
        Action   = ["ecs:UpdateService"]
        Resource = local.nginx_service_arn
      }
    ]
  })
}

# --- Certbot task definition ------------------------------------------------
resource "aws_ecs_task_definition" "certbot" {
  family                   = "${local.name_prefix}-certbot"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  execution_role_arn       = data.aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.certbot_task.arn

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
      name      = "certbot"
      image     = "${aws_ecr_repository.certbot.repository_url}:${var.certbot_image_tag}"
      essential = true
      # Short-lived issue/renew run; 128 fits the instance's tight free memory.
      # Stage C right-sizes nginx (256→128) to leave comfortable headroom for
      # the scheduled runs.
      memory = 128

      environment = [
        { name = "CERT_DOMAIN", value = var.cert_domain },
        { name = "CERTBOT_EMAIL", value = var.certbot_email },
        { name = "ECS_CLUSTER", value = data.aws_ecs_cluster.main.cluster_name },
        { name = "NGINX_SERVICE", value = aws_ecs_service.nginx.name },
        # boto3 in the deploy-hook needs a region for the regional ECS API.
        { name = "AWS_REGION", value = var.aws_region }
      ]

      mountPoints = [
        { sourceVolume = "letsencrypt", containerPath = "/etc/letsencrypt", readOnly = false }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.certbot.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "certbot"
        }
      }
    }
  ])

  tags = {
    Name        = "${local.name_prefix}-certbot-task"
    Environment = var.environment
  }
}

# --- EventBridge schedule: run certbot twice daily --------------------------
resource "aws_iam_role" "eventbridge_certbot" {
  name = "${local.name_prefix}-certbot-events-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "${local.name_prefix}-certbot-events-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "eventbridge_certbot" {
  name = "${local.name_prefix}-certbot-events-policy"
  role = aws_iam_role.eventbridge_certbot.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecs:RunTask"]
        Resource = replace(aws_ecs_task_definition.certbot.arn, "/:\\d+$/", ":*")
        Condition = {
          ArnLike = { "ecs:cluster" = data.aws_ecs_cluster.main.arn }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = [data.aws_iam_role.ecs_execution.arn, aws_iam_role.certbot_task.arn]
      }
    ]
  })
}

resource "aws_cloudwatch_event_rule" "certbot_schedule" {
  name                = "${local.name_prefix}-certbot-schedule"
  description         = "Run certbot renew for ${var.cert_domain} twice daily"
  schedule_expression = "rate(12 hours)"

  tags = {
    Name        = "${local.name_prefix}-certbot-schedule"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_event_target" "certbot" {
  rule     = aws_cloudwatch_event_rule.certbot_schedule.name
  arn      = data.aws_ecs_cluster.main.arn
  role_arn = aws_iam_role.eventbridge_certbot.arn

  ecs_target {
    task_definition_arn = aws_ecs_task_definition.certbot.arn
    task_count          = 1
    launch_type         = "EC2"
  }
}

# --- Outputs ----------------------------------------------------------------
output "letsencrypt_efs_id" {
  description = "EFS file system holding /etc/letsencrypt"
  value       = aws_efs_file_system.letsencrypt.id
}

output "letsencrypt_access_point_id" {
  description = "EFS access point for the certbot + nginx mounts"
  value       = aws_efs_access_point.letsencrypt.id
}

output "certbot_ecr_repository_url" {
  description = "ECR repo URL for the certbot renewal image"
  value       = aws_ecr_repository.certbot.repository_url
}

output "certbot_task_definition_family" {
  description = "Certbot task definition family (run manually to bootstrap)"
  value       = aws_ecs_task_definition.certbot.family
}
