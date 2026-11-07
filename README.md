# CRM Reference Architecture – Infrastructure

Every permutation of **cloud × API runtime × database engine** comes from the same container images and the same Terraform contract:

| Dimension   | Options                                                                 |
|-------------|-------------------------------------------------------------------------|
| Cloud       | `local` (plain Docker), `aws` (LocalStack for AWS), `azure` (LocalStack for Azure) |
| API runtime | `csharp` (CrmApiCSharp), `kotlin` (CrmApiKotlinSpringBoot)              |
| DB engine   | `ms` (SQL Server, DACPAC), `pg` (PostgreSQL, versioned migrations)      |

That gives 3 × 2 × 2 = **12 permutations**. Each API serves both engines at runtime through `/api/{ms|pg}/v1/...`.

Follow the [Infrastructure Coding Standards](file:///Users/cy/codes/localstack-reference-architecture/crm-infra/CODING_STANDARDS.md) when changing anything here. The design rationale and sources are in [ADR 10–13](file:///Users/cy/codes/localstack-reference-architecture/docs/architecture-decisions.md).

## Provider mapping

| Concern         | AWS                                   | Azure                                        |
|-----------------|---------------------------------------|----------------------------------------------|
| Image registry  | Amazon ECR                            | Azure Container Registry                     |
| Compute         | ECS Fargate + Application Load Balancer | Azure Container Apps (external ingress)    |
| SQL Server      | RDS for SQL Server (Express)          | Azure SQL Database                           |
| PostgreSQL      | RDS for PostgreSQL 16                 | Azure Database for PostgreSQL Flexible Server 16 |
| Secrets         | AWS Secrets Manager → task secrets    | Container App secrets                        |
| Schema deploy   | Database image as a one-shot migrator | Same migrator image                          |

Portability comes from the shared modules in `terraform/modules/shared`:

- `crm-catalog` defines what gets deployed (runtimes, engines, ports, health paths).
- `crm-runtime-config` defines the environment contract. Both APIs receive the same ADO.NET connection strings, and only the variable spelling differs.
- `container-image` builds with a content hash and pushes to any OCI registry.
- `database-schema` reuses `CRMDatabaseMS/publish.sh` and `CRMDatabasePG` migrations against any endpoint.

Only `terraform/modules/aws` and `terraform/modules/azure` are provider-specific. To migrate a workload, run the same permutation against the other stack.

## Prerequisites

- Docker Desktop (≥ 8 GB RAM recommended when running both emulators).
- Terraform ≥ 1.9 and `jq`: `brew install hashicorp/tap/terraform jq`.
- A LocalStack auth token for the `aws` and `azure` targets (required since March 2026).

## Setup

```bash
cp crm-infra/.env.example crm-infra/.env   # then set LOCALSTACK_AUTH_TOKEN (and any real cloud keys)
```

Per-service `.env.example` files in `CrmApiCSharp/` and `CrmApiKotlinSpringBoot/` document the container contract for running an image on its own.

## Usage

```bash
# Local Docker (no cloud): both DBs + both APIs
./crm-infra/scripts/up.sh local
./crm-infra/scripts/smoke.sh local [--bruno]

# Emulated clouds: permutation = all | csharp-ms | csharp-pg | kotlin-ms | kotlin-pg
./crm-infra/scripts/up.sh aws   kotlin-pg
./crm-infra/scripts/up.sh azure kotlin-pg          # same permutation, migrated to Azure
./crm-infra/scripts/smoke.sh azure kotlin-pg --bruno

# Tear down (idempotent)
./crm-infra/scripts/down.sh azure kotlin-pg --stop-emulator
./crm-infra/scripts/down.sh local
```

Reads (`GET`) are anonymous; create/update need the `user` or `admin` role and delete needs `admin` (see ADR 14). Mint a local-development token for manual calls (the `--bruno` smoke run mints its own):

```bash
curl -X POST http://localhost:8081/api/pg/v1/hubspot/companies \
  -H "Authorization: Bearer $(./crm-infra/scripts/dev-token.sh user)" \
  -H "Content-Type: application/json" -d '{"name":"Acme"}'
```

Each permutation gets its own Terraform workspace, so several can run side by side. Both emulators can also run at the same time: AWS on `:4566`/`4510-4559`, Azure on `:4567`/`4610-4659`.

Quick checks once a stack is up:

```bash
awslocal ecs list-services --cluster crm-all
terraform -chdir=crm-infra/terraform/azure output permutations
```

## Real clouds

Set `TF_VAR_localstack_enabled=false` and put real credentials in `crm-infra/.env` (`AWS_*` or `ARM_*`). For Azure Container Apps, also use `TF_VAR_image_platform=linux/amd64`. Before you deploy, restrict `database_admin_cidrs` / `database_firewall_rules` to your IP.

## Tests

Offline tests use mocked providers and need no emulator:

```bash
terraform -chdir=crm-infra/terraform/aws test
terraform -chdir=crm-infra/terraform/azure test
```
