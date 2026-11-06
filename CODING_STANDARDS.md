# Infrastructure (crm-infra/) Coding Standards & Best Practices

This document is the complete, self-contained specification of both the **Universal Coding Standards** and the **Terraform / HCL, LocalStack Cloud Emulation, Docker Compose, Container Image, and Bash Lifecycle Script Standards** for the **`crm-infra/`** repository of the workspace.

The `crm-infra/` repository deploys every permutation of **cloud (`local` / `aws` / `azure`) × API runtime (`csharp` / `kotlin`) × database engine (`ms` / `pg`)** from the same container images and the same Terraform contract. See [crm-infra/README.md](file:///Users/cy/codes/localstack-reference-architecture/crm-infra/README.md) for usage, [ADR 10–13](file:///Users/cy/codes/localstack-reference-architecture/docs/architecture-decisions.md) for the design rationale and authoritative sources, and the workspace [Master Coding Standards](file:///Users/cy/codes/localstack-reference-architecture/CODING_STANDARDS.md) for the universal rules.

---

# Part I: Universal Coding Standards

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Universal Standards Pillars                     │
├───────────────────┬───────────────────┬────────────────────────────────┤
│  Functional First │ Immutable Always  │ Explicit Side Effects          │
│  for-expressions  │ locals & readonly │ Pure Modules vs I/O Modules    │
├───────────────────┴──────┬────────────┴────────────────────────────────┤
│  Shared Modules & lib.sh │ Zero Magic Numbers & Anti-Pattern Tolerance │
└──────────────────────────┴─────────────────────────────────────────────┘
```

## 1. Core Universal Principles

1. **Functional Logic Over Imperative Loops**:
   - In HCL, derive collections with declarative `for` expressions, `for_each`, `flatten`, `distinct`, `merge`, `one`, and `try` (e.g. `{ for runtime in var.api_runtimes : runtime => module.catalog.api_runtimes[runtime] }`).
   - Prefer `for_each` over a map or set for collections of resources/modules. Reserve `count` strictly for `0`/`1` feature toggles (e.g. `count = var.push_enabled ? 1 : 0`).
   - In Bash, prefer `jq` / `awk` pipelines for data transformation (e.g. `terraform output -json permutations | jq -r 'to_entries[] | ...'`).
   - **Acceptable Exceptions for Loops**: Bash has no native `map` primitive, so `for` loops are permitted for (a) bounded retry/polling probes (`wait_for_url`) and (b) iterating fixed `readonly` arrays inside a function documented as a *Pure query*. Loop bodies must stay small and free of hidden mutations.
2. **Immutability by Default**:
   - Terraform `locals` are immutable by construction; compute derived values once in `locals` and reference them, never re-derive inline.
   - Bash constants must be declared `readonly` (`readonly SUPPORTED_TARGETS=("local" "aws" "azure")`).
   - Published artifacts are immutable: container images are tagged by **content hash**, and registries enforce immutable tags (`image_tag_mutability = "IMMUTABLE"` on Amazon ECR).
3. **Explicit Demarcation of Side Effects (Functional Core, Imperative Shell)**:
   - **Pure modules** (`modules/shared/crm-catalog`, `modules/shared/crm-runtime-config`, `modules/shared/endpoint-address`) contain only `variable`, `locals`, and `output` blocks — **no resources, no providers, no provisioners**. Their header comment must state `(pure, cloud-agnostic)` or `(pure helper)`.
   - **Side-effecting modules** (`modules/shared/container-image`, `modules/shared/database-schema`, `modules/aws/*`, `modules/azure/*`) own every resource, provider requirement, and `local-exec` provisioner.
   - In Bash, every function that mutates the shell, filesystem, Docker, or Terraform state is preceded by a `# Side effect: ...` comment; read-only helpers are preceded by `# Pure query: ...`.
4. **Zero Magic Numbers & String Literals**:
   - Ports, lengths, retry counts, timeouts, SSL modes, and CPU architectures are named in `locals` (`container_http_port`, `password_length`, `postgres_ssl_mode`, `cpu_architectures`) or Bash `readonly` constants (`DEFAULT_LOCALSTACK_AWS_PORT`, `MAX_ATTEMPTS`, `RETRY_SLEEP_SECONDS`).
   - Compose files expose every tunable through `${VARIABLE:-default}` interpolation backed by [`crm-infra/.env.example`](file:///Users/cy/codes/localstack-reference-architecture/crm-infra/.env.example).
5. **Eliminate Redundancy via Shared Modules & Helper Functions**:
   - Anything describing **what** is deployed (runtimes, engines, ports, health paths, connection-string shape) lives once in `modules/shared` and is consumed identically by the AWS and Azure stacks.
   - Repeated shell workflows live once in [`crm-infra/scripts/lib.sh`](file:///Users/cy/codes/localstack-reference-architecture/crm-infra/scripts/lib.sh) (`compose`, `terraform_stack`, `prepare_stack`, `validate_target`, `require_command`, ...), which is `source`d — never executed — by `up.sh`, `down.sh`, and `smoke.sh`.

---

# Part II: Terraform, LocalStack, Container & Script Standards

## 2. Directory Layout & Module Taxonomy

```
crm-infra/
├── compose.yaml                 # Profiles: local | aws | azure
├── .env.example                 # Documented environment contract (copy to git-ignored .env)
├── permutations/*.tfvars        # all | csharp-ms | csharp-pg | kotlin-ms | kotlin-pg
├── scripts/                     # lib.sh (sourced helpers) + up.sh / down.sh / smoke.sh
└── terraform/
    ├── aws/   azure/            # Root stacks: main.tf, variables.tf, outputs.tf, providers.tf, versions.tf, tests/
    └── modules/
        ├── shared/              # Cloud-agnostic: crm-catalog, crm-runtime-config, container-image, database-schema, endpoint-address
        ├── aws/                 # AWS-only: network, rds-database, ecs-service
        └── azure/               # Azure-only: container-app, mssql-database, postgresql-flexible
```

1. Every module follows the HashiCorp standard module structure: `main.tf`, `variables.tf`, `outputs.tf` (plus `providers.tf` / `versions.tf` in root stacks only).
2. Provider-specific resources **must not** appear in `modules/shared`. A new cloud is added by writing a new `modules/<cloud>` set and a new root stack — never by branching inside shared modules.
3. Every `main.tf` starts with a `# ====` banner describing the module's responsibility and whether it is pure or side-effecting.

## 3. Terraform / HCL Style

1. **Formatting**: All HCL must pass `terraform fmt -check -recursive crm-infra/terraform`. Aligned `=` signs and two-space indentation are mandatory.
2. **Naming**: `snake_case` for resources, variables, locals, and outputs. Name singleton resources `this` (`aws_ecs_cluster.this`, `azurerm_resource_group.this`).
3. **Variables**: Every `variable` declares `description` and `type`. Enum-like inputs declare a `validation` block with an actionable `error_message` (e.g. `api_runtimes` ⊆ `[csharp, kotlin]`, `image_platform` ∈ `[linux/arm64, linux/amd64]`).
4. **Version Pinning**: Root stacks pin `required_version = ">= 1.9"` and pessimistic provider constraints (`~> 6.0` AWS, `~> 5.1` AzureRM, `~> 4.0` Docker, `~> 3.9` Random) in `versions.tf`. Child modules declare only the provider `source`, inheriting versions from the root. `.terraform.lock.hcl` files are committed (see [`.gitignore`](file:///Users/cy/codes/localstack-reference-architecture/crm-infra/.gitignore)) so the exact provider versions and checksums are pinned across machines.
5. **Tagging**: Apply provider `default_tags` from `local.common_tags` on AWS (`Project`, `Permutation`, `ManagedBy = "terraform"`, `Emulated`) and pass `local.tags` to every Azure resource (`project`, `permutation`, `managed-by = "terraform"`, `emulated`), following each cloud's tag-casing convention.
6. **Explicit Dependencies Only When Implicit Ones Are Impossible**: Use `depends_on` only for ordering that cannot be expressed through references (e.g. API services wait for `module.database_schema`).

## 4. Cloud Portability Contract

1. **Single Source of Truth**: [`crm-catalog`](file:///Users/cy/codes/localstack-reference-architecture/crm-infra/terraform/modules/shared/crm-catalog/main.tf) is the only place that lists API runtimes, database engines, container ports, health paths, and migrator platforms.
2. **Identical Runtime Configuration**: [`crm-runtime-config`](file:///Users/cy/codes/localstack-reference-architecture/crm-infra/terraform/modules/shared/crm-runtime-config/main.tf) emits the **same ADO.NET-style connection string** per engine for both runtimes; only the variable spelling differs (`ConnectionStrings__CRMDatabaseMS` for .NET, `CONNECTIONSTRINGS_CRMDATABASEMS` for Spring relaxed binding). Compute modules consume `environment` and `secrets` maps verbatim.
3. **One Permutation per Workspace**: Each permutation maps to its own Terraform workspace (`default` ⇔ `all`) and its own `permutations/<name>.tfvars`. Resource names derive from `"${var.project_name}-${local.permutation}"` so permutations coexist side by side.
4. **Same Images Everywhere**: Local Docker, ECS Fargate, and Azure Container Apps run the exact images built from each sub-repository `Dockerfile`. No cloud-specific image variants.

## 5. LocalStack Emulation Standards

1. **Emulator by Default, Real Cloud by Flag**: `localstack_enabled` defaults to `true`. Real-cloud deployment is achieved by `TF_VAR_localstack_enabled=false` plus real credentials — never by editing modules.
2. **Endpoint Overrides Are Conditional**: AWS service `endpoints` and `skip_credentials_validation` / `skip_metadata_api_check` / `skip_requesting_account_id` are enabled **only** when `localstack_enabled`; AzureRM uses `metadata_host` only when emulated.
3. **Ports**: LocalStack for AWS uses gateway `:4566` with service ports `4510-4559`; LocalStack for Azure uses gateway `:4567` with service ports `4610-4659`, so both emulators can run concurrently. Inside Docker networks, address emulators by service/container name, never `localhost`.
4. **Dummy Credentials**: Emulated runs use `AWS_ACCESS_KEY_ID=test`, `AWS_SECRET_ACCESS_KEY=test`, `AWS_DEFAULT_REGION=us-east-1`, and any service principal for LocalStack for Azure.
5. **Auth Token Handling**: `LOCALSTACK_AUTH_TOKEN` is read exclusively from the git-ignored `crm-infra/.env`; scripts fail fast via `require_auth_token` when it is empty.
6. **Loopback Rewriting**: When an emulated endpoint resolves to `localhost` / `127.0.0.1`, host-side migrators are pointed at `host.docker.internal` (named in `locals`, never inlined).

## 6. Secrets & Security

1. Generate database credentials with `random_password` (length and character classes defined in `locals`). Never hard-code passwords in `.tf` or `.tfvars` files.
2. Mark every output and variable carrying credentials or connection strings `sensitive = true`.
3. Connection strings reach containers **only** through the platform secret store (AWS Secrets Manager → ECS task `secrets`, Azure Container App `secret` + `secret_name`), never through plain `environment` maps.
4. Migrator credentials travel through `local-exec` `environment`, never on the command line. Any `nonsensitive(...)` call must carry an inline comment justifying it.
5. Bind published host ports to `${HOST_BIND_ADDRESS:-127.0.0.1}`. Restrict `database_admin_cidrs` / `database_firewall_rules` to a known IP before any real-cloud deployment.
6. Never commit `crm-infra/.env`, `crm-infra/.localstack/`, `*.tfstate`, `*.tfplan`, or `.terraform/` (all ignored by [`crm-infra/.gitignore`](file:///Users/cy/codes/localstack-reference-architecture/crm-infra/.gitignore)).

## 7. Container Images & Schema Migrators

1. **Multi-Stage, Non-Root Images**: Sub-repository Dockerfiles build in an SDK/JDK stage and run on a minimal runtime stage as a non-root user. All environment-specific settings are injected at runtime through environment variables documented in each repository's `.env.example`.
2. **Content-Addressed Tags**: [`container-image`](file:///Users/cy/codes/localstack-reference-architecture/crm-infra/terraform/modules/shared/container-image/main.tf) derives tags from a SHA-1 of the build context, so compute rolls out automatically when — and only when — source changes. Never deploy `:latest` application images.
3. **OCI Labels**: Images carry `org.opencontainers.image.title` / `.description` labels.
4. **One-Shot Migrators**: [`database-schema`](file:///Users/cy/codes/localstack-reference-architecture/crm-infra/terraform/modules/shared/database-schema/main.tf) reuses each database repository image as an admin process (`CRMDatabaseMS/publish.sh`, `CRMDatabasePG` init entrypoint). It re-runs only when the image, endpoint, or seed mode changes (`terraform_data.triggers_replace`).

## 8. Bash Lifecycle Scripts

1. Begin every executable script with `#!/usr/bin/env bash`, a `# ====` usage banner, and `set -euo pipefail`.
2. `source` shared helpers with a `# shellcheck source=lib.sh` directive; `lib.sh` itself is sourced, never executed.
3. Declare constants `readonly`; quote every expansion (`"${var}"`); use `local` for function variables.
4. Validate positional arguments up front (`validate_target`, `validate_permutation`) and fail fast with `die "<actionable message>"`.
5. Check prerequisites with `require_command <tool> "<install hint>"`.
6. Scripts must be **idempotent**: `terraform workspace select -or-create=true`, `terraform destroy`, and `docker compose down --volumes` may be re-run safely.
7. Indent with 4 spaces (matching the `shfmt -i 4` pre-commit formatter).

## 9. Docker Compose

1. Group services into **profiles** (`local`, `aws`, `azure`) that can be combined freely.
2. Every long-running service defines a `healthcheck`; dependents use `depends_on: { condition: service_healthy }`, and scripts start stacks with `up -d --wait`.
3. Share repeated configuration through YAML anchors (`x-localstack-common: &localstack-common`).
4. Use fixed, non-overlapping service port ranges so emulators can run side by side.

## 10. Testing & Verification

1. **Static gates** (run before every commit touching `crm-infra/terraform`):
   ```bash
   terraform fmt -check -recursive crm-infra/terraform
   terraform -chdir=crm-infra/terraform/aws validate
   terraform -chdir=crm-infra/terraform/azure validate
   ```
2. **Offline contract tests**: `terraform -chdir=crm-infra/terraform/<aws|azure> test` uses `mock_provider` blocks and `override_module` for the host-side migrator, so no emulator or Docker build is needed. Each stack must cover the `all` permutation, at least one single-runtime/single-engine permutation, and negative `validation` cases via `expect_failures`.
3. **Live verification**: `./crm-infra/scripts/smoke.sh <local|aws|azure> [permutation] [--bruno]` probes health and sample REST resources, optionally running the full Bruno suites.

## 11. Anti-Patterns & Common Mistakes Catalog for Infrastructure

1. **Cloud Logic Leaking into Shared Modules**:
   - *Violation*: Adding an `aws_*` / `azurerm_*` resource or provider-specific branching to `modules/shared`.
   - *Remedy*: Keep shared modules pure or provider-neutral (Docker only); put provider resources in `modules/<cloud>`.
2. **`count` over Collections**:
   - *Violation*: `count = length(var.api_runtimes)` with index-based addressing, which reshuffles resources when the list changes.
   - *Remedy*: `for_each` over a map/set keyed by stable identifiers (`csharp`, `kotlin`, `ms`, `pg`).
3. **Secrets in Plain Environment or Command Lines**:
   - *Violation*: Passing connection strings via `environment`, `docker run -e NAME=value`, or non-sensitive outputs.
   - *Remedy*: Platform secret stores, `local-exec` `environment`, and `sensitive = true`.
4. **Mutable Image Tags**:
   - *Violation*: Deploying `:latest` or re-pushing an existing tag.
   - *Remedy*: Content-hash tags with immutable registries.
5. **Hard-Coded Emulator Endpoints**:
   - *Violation*: Inlining `http://localhost:4566` in modules.
   - *Remedy*: `var.localstack_endpoint` / `var.localstack_metadata_host`, exported by `export_localstack_tf_vars`.
6. **Silent Script Failures**:
   - *Violation*: Missing `set -euo pipefail`, unquoted expansions, or ignoring exit codes with `|| true` without justification.
   - *Remedy*: Strict mode, quoting, and `die` with actionable messages.

---

## 12. Pre-Commit Formatting

- `crm-infra/` is its own Git repository. [`.githooks/install-hooks.sh`](file:///Users/cy/codes/localstack-reference-architecture/.githooks/install-hooks.sh) installs the workspace [`.githooks/pre-commit`](file:///Users/cy/codes/localstack-reference-architecture/.githooks/pre-commit) hook into it; the hook formats staged `.sh` files (`shfmt -i 4`, when installed), validates Bash syntax (`bash -n`), and normalizes whitespace/newlines.
- The hook does not yet run `terraform fmt`; run `terraform fmt -recursive crm-infra/terraform` before committing HCL changes.
