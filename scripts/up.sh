#!/usr/bin/env bash
# ============================================================================
# Deploy a CRM permutation.
#   ./crm-infra/scripts/up.sh local                 # plain Docker, both APIs x both DBs
#   ./crm-infra/scripts/up.sh aws   [permutation]   # LocalStack for AWS   (ECS + RDS)
#   ./crm-infra/scripts/up.sh azure [permutation]   # LocalStack for Azure (Container Apps + Azure SQL/PostgreSQL)
# permutation: all (default) | csharp-ms | csharp-pg | kotlin-ms | kotlin-pg
# Each permutation lives in its own Terraform workspace, so several can coexist.
# ============================================================================
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

readonly TARGET="${1:-}"
readonly PERMUTATION="${2:-${DEFAULT_PERMUTATION}}"

[ -n "${TARGET}" ] || die "Usage: $(basename "$0") <local|aws|azure> [permutation]"
validate_target "${TARGET}"
validate_permutation "${PERMUTATION}"

require_command docker "Install Docker Desktop: https://docs.docker.com/get-docker/"
load_env

if [ "${TARGET}" = "local" ]; then
    log "Building and starting the local profile (both databases + both APIs)..."
    compose --profile local up -d --build --wait
    log "Local permutations:"
    local_permutation_urls | awk '{ printf "  %-20s %s\n", $1, $2 }'
    exit 0
fi

require_command terraform "Install Terraform >= 1.9: brew install hashicorp/tap/terraform"
require_command jq "Install jq: brew install jq"
require_auth_token

log "Starting LocalStack for ${TARGET}..."
compose --profile "${TARGET}" up -d --wait

export_localstack_tf_vars "${TARGET}"
prepare_stack "${TARGET}" "${PERMUTATION}"

log "Applying ${TARGET} permutation '${PERMUTATION}' (workspace $(workspace_for "${PERMUTATION}"))..."
terraform_stack "${TARGET}" apply -input=false -auto-approve -var-file="$(var_file_for "${PERMUTATION}")"

log "Deployed permutations:"
cloud_permutation_urls "${TARGET}" | awk '{ printf "  %-20s %s\n", $1, $2 }'
log "Run ./crm-infra/scripts/smoke.sh ${TARGET} ${PERMUTATION} to verify them."
