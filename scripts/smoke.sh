#!/usr/bin/env bash
# ============================================================================
# Smoke-test every deployed permutation of a target.
#   ./crm-infra/scripts/smoke.sh <local|aws|azure> [permutation] [--bruno]
# Probes /health/{ms|pg} and a sample REST resource per permutation; --bruno
# additionally runs the full Bruno suite of each API against the deployment.
# ============================================================================
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

readonly BRUNO_FLAG="--bruno"
POSITIONAL_ARGS=()
RUN_BRUNO=""
for arg in "$@"; do
    if [ "${arg}" = "${BRUNO_FLAG}" ]; then
        RUN_BRUNO="${BRUNO_FLAG}"
    else
        POSITIONAL_ARGS+=("${arg}")
    fi
done
readonly RUN_BRUNO
readonly TARGET="${POSITIONAL_ARGS[0]:-}"
readonly PERMUTATION="${POSITIONAL_ARGS[1]:-${DEFAULT_PERMUTATION}}"
readonly MAX_ATTEMPTS=30
readonly RETRY_SLEEP_SECONDS=5
readonly REQUEST_TIMEOUT_SECONDS=10
readonly REPOSITORY_ROOT="$(cd "${INFRA_DIR}/.." && pwd)"

[ -n "${TARGET}" ] || die "Usage: $(basename "$0") <local|aws|azure> [permutation] [${BRUNO_FLAG}]"
validate_target "${TARGET}"
validate_permutation "${PERMUTATION}"
require_command curl "Install curl."
load_env

wait_for_url() {
    local url="$1"
    for _ in $(seq 1 "${MAX_ATTEMPTS}"); do
        if curl -sf --max-time "${REQUEST_TIMEOUT_SECONDS}" "${url}" >/dev/null 2>&1; then
            return 0
        fi
        sleep "${RETRY_SLEEP_SECONDS}"
    done
    return 1
}

bruno_environment_for() {
    local engine="$1"
    if [ "${engine}" = "ms" ]; then
        echo "Local-MsSql"
    else
        echo "Local-Postgres"
    fi
}

bruno_project_for() {
    local runtime="$1"
    if [ "${runtime}" = "csharp" ]; then
        echo "${REPOSITORY_ROOT}/CrmApiCSharp"
    else
        echo "${REPOSITORY_ROOT}/CrmApiKotlinSpringBoot"
    fi
}

if [ "${TARGET}" = "local" ]; then
    PERMUTATION_URLS="$(local_permutation_urls)"
else
    require_command terraform "Install Terraform >= 1.9: brew install hashicorp/tap/terraform"
    require_command jq "Install jq: brew install jq"
    export_localstack_tf_vars "${TARGET}"
    prepare_stack "${TARGET}" "${PERMUTATION}"
    PERMUTATION_URLS="$(cloud_permutation_urls "${TARGET}")"
fi

FAILURES=0
while read -r name health_url resource_url; do
    [ -n "${name}" ] || continue
    if wait_for_url "${health_url}" && curl -sf --max-time "${REQUEST_TIMEOUT_SECONDS}" "${resource_url}" >/dev/null; then
        echo "  [PASS] ${name}"
    else
        echo "  [FAIL] ${name} (${health_url})"
        FAILURES=$((FAILURES + 1))
    fi

    if [ "${RUN_BRUNO}" = "${BRUNO_FLAG}" ]; then
        runtime="$(echo "${name}" | cut -d- -f2)"
        engine="$(echo "${name}" | cut -d- -f3)"
        base_url="${health_url%/health/*}"
        "$(bruno_project_for "${runtime}")/bruno/run_tests.sh" "$(bruno_environment_for "${engine}")" --env-var "baseUrl=${base_url}" </dev/null \
        || FAILURES=$((FAILURES + 1))
    fi
done <<<"${PERMUTATION_URLS}"

[ "${FAILURES}" -eq 0 ] || die "${FAILURES} permutation check(s) failed."
log "All ${TARGET} permutations are healthy."
