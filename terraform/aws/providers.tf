# ----------------------------------------------------------------------------
# AWS provider: LocalStack by default, real AWS when localstack_enabled=false.
# Credentials come from the standard AWS_* environment variables (crm-infra/.env).
# ----------------------------------------------------------------------------
provider "aws" {
  region = var.aws_region

  s3_use_path_style           = var.localstack_enabled
  skip_credentials_validation = var.localstack_enabled
  skip_metadata_api_check     = var.localstack_enabled
  skip_requesting_account_id  = var.localstack_enabled

  dynamic "endpoints" {
    for_each = var.localstack_enabled ? [var.localstack_endpoint] : []
    content {
      cloudwatchlogs = endpoints.value
      ec2            = endpoints.value
      ecr            = endpoints.value
      ecs            = endpoints.value
      elbv2          = endpoints.value
      iam            = endpoints.value
      rds            = endpoints.value
      secretsmanager = endpoints.value
      sts            = endpoints.value
    }
  }

  default_tags {
    tags = local.common_tags
  }
}

# Local Docker daemon (honours DOCKER_HOST) used to build images and run schema migrators.
provider "docker" {}
