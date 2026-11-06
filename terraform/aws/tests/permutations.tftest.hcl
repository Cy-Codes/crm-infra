# ============================================================================
# Offline permutation tests for the AWS stack (no LocalStack required).
# Providers are mocked and the host-side schema migrator is overridden, so the
# suite verifies wiring, naming and the runtime configuration contract only.
#   terraform -chdir=crm-infra/terraform/aws test
# ============================================================================

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b"]
    }
  }

  mock_data "aws_ecr_authorization_token" {
    defaults = {
      proxy_endpoint = "https://000000000000.dkr.ecr.us-east-1.localhost.localstack.cloud:4566"
      user_name      = "AWS"
      password       = "test"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{}"
    }
  }

  mock_resource "aws_db_instance" {
    defaults = {
      address = "localhost.localstack.cloud"
      port    = 4510
    }
  }

  mock_resource "aws_lb" {
    defaults = {
      arn      = "arn:aws:elasticloadbalancing:us-east-1:000000000000:loadbalancer/app/crm/0123456789abcdef"
      dns_name = "crm.elb.localhost.localstack.cloud"
    }
  }

  mock_resource "aws_lb_target_group" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:000000000000:targetgroup/crm/0123456789abcdef"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::000000000000:role/crm-execution"
    }
  }

  mock_resource "aws_secretsmanager_secret" {
    defaults = {
      arn = "arn:aws:secretsmanager:us-east-1:000000000000:secret:crm-AbCdEf"
    }
  }

  mock_resource "aws_ecs_task_definition" {
    defaults = {
      arn = "arn:aws:ecs:us-east-1:000000000000:task-definition/crm:1"
    }
  }

  mock_resource "aws_ecs_cluster" {
    defaults = {
      arn = "arn:aws:ecs:us-east-1:000000000000:cluster/crm"
    }
  }

  mock_resource "aws_ecr_repository" {
    defaults = {
      repository_url = "000000000000.dkr.ecr.us-east-1.localhost.localstack.cloud:4566/crm"
    }
  }
}

mock_provider "docker" {}

override_module {
  target = module.database_schema
  outputs = {
    deployment_id = "mocked"
  }
}

run "all_permutations" {
  command = apply

  assert {
    condition     = toset(keys(output.permutations)) == toset(["aws-csharp-ms", "aws-csharp-pg", "aws-kotlin-ms", "aws-kotlin-pg"])
    error_message = "The default permutation must expose all four AWS permutations."
  }

  assert {
    condition     = output.permutations["aws-kotlin-pg"].health_url == "http://crm.elb.localhost.localstack.cloud:4566/health/pg"
    error_message = "LocalStack load balancer URLs must be routed through the LocalStack gateway port."
  }

  assert {
    condition     = startswith(module.runtime_config.secrets["kotlin"]["CONNECTIONSTRINGS_CRMDATABASEPG"], "Host=localhost.localstack.cloud;Port=4510;Database=CRMDatabase;Username=crmadmin;")
    error_message = "Kotlin must receive a connection string that targets the RDS PostgreSQL endpoint."
  }

  assert {
    condition     = sort(values(module.runtime_config.secrets["kotlin"])) == sort(values(module.runtime_config.secrets["csharp"]))
    error_message = "Both runtimes must receive identical connection strings (only the variable spelling differs)."
  }

  assert {
    condition     = toset(module.runtime_config.secret_names["csharp"]) == toset(["ConnectionStrings__CRMDatabaseMS", "ConnectionStrings__CRMDatabasePG"])
    error_message = "C# must receive both connection strings as secrets."
  }

  assert {
    condition     = startswith(module.runtime_config.secrets["csharp"]["ConnectionStrings__CRMDatabaseMS"], "Server=localhost.localstack.cloud,4510;Database=CRMDatabaseMS;User Id=crmadmin;")
    error_message = "C# SQL Server connection string must target the RDS SQL Server endpoint."
  }

  assert {
    condition     = can(regex("^000000000000\\.dkr\\.ecr\\.us-east-1\\.localhost\\.localstack\\.cloud:4566/crm:[0-9a-f]{12}$", output.container_images["csharp"]))
    error_message = "API images must be pushed to the ECR repository with a content-hash tag."
  }
}

run "csharp_on_sql_server_only" {
  command = apply

  variables {
    api_runtimes     = ["csharp"]
    database_engines = ["ms"]
  }

  assert {
    condition     = keys(output.permutations) == ["aws-csharp-ms"]
    error_message = "Only the aws-csharp-ms permutation must be deployed."
  }

  assert {
    condition     = keys(module.database) == ["ms"] && keys(module.api_service) == ["csharp"]
    error_message = "Only the SQL Server instance and the C# service must be provisioned."
  }

  assert {
    condition     = module.runtime_config.secret_names["csharp"] == ["ConnectionStrings__CRMDatabaseMS"]
    error_message = "C# must only receive the SQL Server connection string."
  }
}

run "kotlin_on_postgres_only" {
  command = apply

  variables {
    api_runtimes     = ["kotlin"]
    database_engines = ["pg"]
  }

  assert {
    condition     = keys(output.permutations) == ["aws-kotlin-pg"]
    error_message = "Only the aws-kotlin-pg permutation must be deployed."
  }

  assert {
    condition     = module.runtime_config.secret_names["kotlin"] == ["CONNECTIONSTRINGS_CRMDATABASEPG"]
    error_message = "Kotlin must only receive the PostgreSQL connection string."
  }

  assert {
    condition     = length(module.runtime_config.environment["kotlin"]) == 0
    error_message = "Kotlin must not receive plain-text database settings."
  }
}

run "rejects_unknown_runtime" {
  command = plan

  variables {
    api_runtimes = ["python"]
  }

  expect_failures = [var.api_runtimes]
}
