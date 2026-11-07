# ============================================================================
# CRM Reference Architecture - AWS Stack
#   ECR (images) -> RDS SQL Server / PostgreSQL -> schema migrators
#   -> ECS Fargate services behind Application Load Balancers
# Every cloud-specific resource lives in modules/aws; everything that defines
# *what* is deployed lives in modules/shared and is identical on Azure.
# ============================================================================

locals {
  repository_root = abspath("${path.root}/../../..")
  permutation     = terraform.workspace == "default" ? "all" : terraform.workspace
  name_prefix     = "${var.project_name}-${local.permutation}"

  common_tags = {
    Project     = var.project_name
    Permutation = local.permutation
    ManagedBy   = "terraform"
    Emulated    = tostring(var.localstack_enabled)
  }

  cpu_architectures = {
    "linux/arm64" = "ARM64"
    "linux/amd64" = "X86_64"
  }

  loopback_hosts         = ["localhost", "127.0.0.1"]
  docker_host_gateway    = "host.docker.internal"
  postgres_ssl_mode      = var.localstack_enabled ? "prefer" : "require"
  trust_server_cert      = var.localstack_enabled ? true : false
  password_length        = 24
  password_special_chars = "!#%*-_"

  api_runtimes     = { for runtime in var.api_runtimes : runtime => module.catalog.api_runtimes[runtime] }
  database_engines = { for engine in var.database_engines : engine => module.catalog.database_engines[engine] }
  api_port         = one(distinct([for api in values(module.catalog.api_runtimes) : api.container_port]))

  registry = {
    address  = trimprefix(data.aws_ecr_authorization_token.this.proxy_endpoint, "https://")
    username = data.aws_ecr_authorization_token.this.user_name
    password = data.aws_ecr_authorization_token.this.password
  }

  databases = {
    for engine, db in module.database : engine => {
      host                     = db.host
      port                     = db.port
      database_name            = local.database_engines[engine].database_name
      username                 = var.db_admin_username
      password                 = random_password.database[engine].result
      ssl_mode                 = local.postgres_ssl_mode
      trust_server_certificate = local.trust_server_cert
    }
  }

  api_base_urls = {
    for runtime, service in module.api_service : runtime => (
      var.localstack_enabled
      ? "http://${service.load_balancer_dns_name}:${var.localstack_gateway_port}"
      : "http://${service.load_balancer_dns_name}"
    )
  }
}

module "catalog" {
  source = "../modules/shared/crm-catalog"

  repository_root = local.repository_root
}

data "aws_ecr_authorization_token" "this" {}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------
module "network" {
  source = "../modules/aws/network"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  api_container_port   = local.api_port
  database_ports       = [for engine in local.database_engines : engine.default_port]
  database_admin_cidrs = var.database_admin_cidrs
}

# ---------------------------------------------------------------------------
# Data tier: RDS instances + schema deployment
# ---------------------------------------------------------------------------
resource "random_password" "database" {
  for_each = local.database_engines

  length           = local.password_length
  special          = true
  override_special = local.password_special_chars
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
}

module "database" {
  source   = "../modules/aws/rds-database"
  for_each = local.database_engines

  name_prefix             = local.name_prefix
  engine                  = each.key
  database_name           = each.value.database_name
  postgres_engine_version = var.postgres_engine_version
  instance_class          = var.db_instance_class
  allocated_storage_gb    = var.db_allocated_storage_gb
  backup_retention_days   = var.db_backup_retention_days
  skip_final_snapshot     = var.db_skip_final_snapshot
  deletion_protection     = var.db_deletion_protection
  username                = var.db_admin_username
  password                = random_password.database[each.key].result
  subnet_ids              = module.network.public_subnet_ids
  security_group_ids      = [module.network.database_security_group_id]
  publicly_accessible     = var.db_publicly_accessible
}

module "database_schema" {
  source   = "../modules/shared/database-schema"
  for_each = local.database_engines

  engine           = each.key
  source_dir       = each.value.source_dir
  image_repository = "${local.name_prefix}-${each.key}-migrator"
  platform         = each.value.migrator_platform
  host             = var.localstack_enabled && contains(local.loopback_hosts, local.databases[each.key].host) ? local.docker_host_gateway : local.databases[each.key].host
  port             = local.databases[each.key].port
  database_name    = local.databases[each.key].database_name
  username         = local.databases[each.key].username
  password         = local.databases[each.key].password
  ssl_mode         = local.databases[each.key].ssl_mode
  seed_data        = var.seed_data
  host_aliases     = var.localstack_enabled && !contains(local.loopback_hosts, local.databases[each.key].host) ? [local.databases[each.key].host] : []
}

module "runtime_config" {
  source = "../modules/shared/crm-runtime-config"

  databases = local.databases
}

# ---------------------------------------------------------------------------
# Compute tier: ECR images + ECS Fargate services
# ---------------------------------------------------------------------------
resource "aws_ecr_repository" "api" {
  for_each = local.api_runtimes

  name                 = "${local.name_prefix}-${each.key}"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

module "api_image" {
  source   = "../modules/shared/container-image"
  for_each = local.api_runtimes

  repository   = aws_ecr_repository.api[each.key].repository_url
  context_dir  = each.value.source_dir
  platform     = var.image_platform
  push_enabled = true
  registry     = local.registry
  labels = {
    "org.opencontainers.image.title"       = each.value.display_name
    "org.opencontainers.image.description" = "CRM API (${each.key}) for permutation ${local.permutation}"
  }
}

resource "aws_ecs_cluster" "this" {
  name = local.name_prefix

  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}

module "api_service" {
  source   = "../modules/aws/ecs-service"
  for_each = local.api_runtimes

  name                            = "${local.name_prefix}-${each.key}"
  region                          = var.aws_region
  cluster_id                      = aws_ecs_cluster.this.id
  image                           = module.api_image[each.key].image_reference
  container_port                  = each.value.container_port
  health_path                     = each.value.health_path
  environment                     = module.runtime_config.environment[each.key]
  secret_names                    = module.runtime_config.secret_names[each.key]
  secrets                         = module.runtime_config.secrets[each.key]
  cpu                             = var.api_task_cpu
  memory                          = var.api_task_memory
  cpu_architecture                = local.cpu_architectures[var.image_platform]
  desired_count                   = var.api_desired_count
  assign_public_ip                = var.api_assign_public_ip
  certificate_arn                 = var.api_certificate_arn
  vpc_id                          = module.network.vpc_id
  subnet_ids                      = module.network.public_subnet_ids
  load_balancer_security_group_id = module.network.load_balancer_security_group_id
  api_security_group_id           = module.network.api_security_group_id
  listener_port                   = module.network.http_listener_port
  https_listener_port             = module.network.https_listener_port
  log_retention_days              = var.log_retention_days

  depends_on = [module.database_schema]
}
