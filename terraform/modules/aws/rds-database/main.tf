# ============================================================================
# Amazon RDS Database Instance (engine-agnostic)
# One module serves both CRM engines; only the engine profile differs:
#   ms -> sqlserver-ex (License Included, database created by the DACPAC publish)
#   pg -> postgres     (initial database created by RDS)
# ============================================================================

locals {
  engine_profiles = {
    ms = {
      engine         = "sqlserver-ex"
      engine_version = var.sqlserver_engine_version
      license_model  = "license-included"
      db_name        = null
    }
    pg = {
      engine         = "postgres"
      engine_version = var.postgres_engine_version
      license_model  = null
      db_name        = var.database_name
    }
  }

  profile = local.engine_profiles[var.engine]
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-${var.engine}"
  subnet_ids = var.subnet_ids

  tags = { Name = "${var.name_prefix}-${var.engine}" }
}

resource "aws_db_instance" "this" {
  identifier     = "${var.name_prefix}-${var.engine}"
  engine         = local.profile.engine
  engine_version = local.profile.engine_version
  license_model  = local.profile.license_model
  db_name        = local.profile.db_name
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage_gb
  storage_type      = "gp3"

  username = var.username
  password = var.password

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.security_group_ids
  publicly_accessible    = var.publicly_accessible

  backup_retention_period = var.backup_retention_days
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true

  tags = { Name = "${var.name_prefix}-${var.engine}" }
}
