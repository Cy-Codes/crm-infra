#!/usr/bin/env bash
# ============================================================================
# Tear down a CRM permutation (idempotent).
#   ./crm-infra/scripts/down.sh local
#   ./crm-infra/scripts/down.sh aws   [permutation] [--stop-emulator]
#   ./crm-infra/scripts/down.sh azure [permutation] [--stop-emulator]
# ============================================================================
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

readonly TARGET="${1:-}"
readonly PERMUTATION="${2:-${DEFAULT_PERMUTATION}}"
readonly STOP_EMULATOR_FLAG="--stop-emulator"
readonly STOP_EMULATOR="${3:-}"

[ -n "${TARGET}" ] || die "Usage: $(basename "$0") <local|aws|azure> [permutation] [${STOP_EMULATOR_FLAG}]"
validate_target "${TARGET}"
validate_permutation "${PERMUTATION}"

require_command docker "Install Docker Desktop: https://docs.docker.com/get-docker/"
load_env

if [ "${TARGET}" = "local" ]; then
    log "Stopping the local profile and removing its volumes..."
    compose --profile local down --volumes --remove-orphans
    exit 0
fi

require_command terraform "Install Terraform >= 1.9: brew install hashicorp/tap/terraform"

export_localstack_tf_vars "${TARGET}"
prepare_stack "${TARGET}" "${PERMUTATION}"

log "Destroying ${TARGET} permutation '${PERMUTATION}'..."
terraform_stack "${TARGET}" destroy -input=false -auto-approve -var-file="$(var_file_for "${PERMUTATION}")"

if [ "${STOP_EMULATOR}" = "${STOP_EMULATOR_FLAG}" ]; then
    log "Stopping LocalStack for ${TARGET}..."
    compose --profile "${TARGET}" down --remove-orphans
fi
