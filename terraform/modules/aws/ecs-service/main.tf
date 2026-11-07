# ============================================================================
# Amazon ECS (Fargate) Service behind an Application Load Balancer
# Runs one CRM API container image. Plain settings become container
# environment variables; secret settings are stored in AWS Secrets Manager
# and injected by the ECS agent at task start.
# ============================================================================

locals {
  ecs_tasks_principal   = "ecs-tasks.amazonaws.com"
  execution_policy_arn  = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  operating_system      = "LINUX"
  log_stream_prefix     = "ecs"
  healthy_status_codes  = "200-399"
  secret_name_separator = "/"

  secret_names = toset(var.secret_names)

  container_definition = {
    name      = var.name
    image     = var.image
    essential = true
    portMappings = [{
      containerPort = var.container_port
      hostPort      = var.container_port
      protocol      = "tcp"
    }]
    environment = [for name in sort(keys(var.environment)) : { name = name, value = var.environment[name] }]
    secrets     = [for name in sort(var.secret_names) : { name = name, valueFrom = aws_secretsmanager_secret.this[name].arn }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.this.name
        awslogs-region        = var.region
        awslogs-stream-prefix = local.log_stream_prefix
      }
    }
  }
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.name}"
  retention_in_days = var.log_retention_days
}

resource "aws_secretsmanager_secret" "this" {
  for_each = local.secret_names

  name                    = "${var.name}${local.secret_name_separator}${each.key}"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "this" {
  for_each = local.secret_names

  secret_id     = aws_secretsmanager_secret.this[each.key].id
  secret_string = var.secrets[each.key]
}

data "aws_iam_policy_document" "ecs_tasks_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = [local.ecs_tasks_principal]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.name}-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = local.execution_policy_arn
}

data "aws_iam_policy_document" "read_secrets" {
  count = length(local.secret_names) > 0 ? 1 : 0

  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [for secret in aws_secretsmanager_secret.this : secret.arn]
  }
}

resource "aws_iam_role_policy" "read_secrets" {
  count = length(local.secret_names) > 0 ? 1 : 0

  name   = "${var.name}-read-secrets"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.read_secrets[0].json
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  container_definitions    = jsonencode([local.container_definition])

  runtime_platform {
    operating_system_family = local.operating_system
    cpu_architecture        = var.cpu_architecture
  }

  depends_on = [aws_secretsmanager_secret_version.this]
}

resource "aws_lb" "this" {
  name               = var.name
  load_balancer_type = "application"
  internal           = false
  subnets            = var.subnet_ids
  security_groups    = [var.load_balancer_security_group_id]
}

resource "aws_lb_target_group" "this" {
  name        = var.name
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    path    = var.health_path
    matcher = local.healthy_status_codes
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.listener_port
  protocol          = "HTTP"

  default_action {
    type = var.certificate_arn != null ? "redirect" : "forward"

    dynamic "redirect" {
      for_each = var.certificate_arn != null ? [1] : []
      content {
        port        = tostring(var.https_listener_port)
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    target_group_arn = var.certificate_arn != null ? null : aws_lb_target_group.this.arn
  }
}

resource "aws_lb_listener" "https" {
  count = var.certificate_arn != null ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = var.https_listener_port
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

resource "aws_ecs_service" "this" {
  name            = var.name
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.api_security_group_id]
    assign_public_ip = var.assign_public_ip
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = var.name
    container_port   = var.container_port
  }

  depends_on = [
    aws_lb_listener.http,
    aws_lb_listener.https,
    aws_iam_role_policy_attachment.execution,
    aws_iam_role_policy.read_secrets
  ]
}
