#!/usr/bin/env bash
# ============================================================================
# Shared helpers for the crm-infra lifecycle scripts (sourced, not executed).
# ============================================================================

readonly INFRA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ENV_FILE="${INFRA_DIR}/.env"
readonly ENV_EXAMPLE_FILE="${INFRA_DIR}/.env.example"
readonly COMPOSE_FILE="${INFRA_DIR}/compose.yaml"
readonly PERMUTATIONS_DIR="${INFRA_DIR}/permutations"
readonly TERRAFORM_ROOT="${INFRA_DIR}/terraform"

readonly SUPPORTED_TARGETS=("local" "aws" "azure")
readonly SUPPORTED_PERMUTATIONS=("all" "csharp-ms" "csharp-pg" "kotlin-ms" "kotlin-pg")
readonly DEFAULT_PERMUTATION="all"

readonly DEFAULT_LOCALSTACK_AWS_PORT=4566
readonly DEFAULT_LOCALSTACK_AZURE_PORT=4567
readonly LOCALSTACK_AZURE_METADATA_HOST="azure.localhost.localstack.cloud"
readonly DEFAULT_LOCAL_CSHARP_API_PORT=8081
readonly DEFAULT_LOCAL_KOTLIN_API_PORT=8082
readonly LOCAL_API_RUNTIMES=("csharp" "kotlin")
readonly DATABASE_ENGINES=("ms" "pg")

log() {
    echo "==> $*"
}

die() {
    echo "Error: $*" >&2
    exit 1
}

contains_element() {
    local needle="$1"
    shift
    printf '%s\n' "$@" | grep -qx -- "${needle}"
}

require_command() {
    local command_name="$1"
    local install_hint="$2"
    command -v "${command_name}" >/dev/null 2>&1 || die "'${command_name}' is required. ${install_hint}"
}

# Side effect: exports every variable of crm-infra/.env into the current shell.
load_env() {
    if [ ! -f "${ENV_FILE}" ]; then
        log "Creating ${ENV_FILE} from .env.example (fill in LOCALSTACK_AUTH_TOKEN)"
        cp "${ENV_EXAMPLE_FILE}" "${ENV_FILE}"
    fi
    set -a
    # shellcheck disable=SC1090
    source "${ENV_FILE}"
    set +a
}

require_auth_token() {
    [ -n "${LOCALSTACK_AUTH_TOKEN:-}" ] || die "LOCALSTACK_AUTH_TOKEN is empty. Add it to ${ENV_FILE} (https://app.localstack.cloud/workspace/auth-tokens)."
}

validate_target() {
    local target="$1"
    contains_element "${target}" "${SUPPORTED_TARGETS[@]}" || die "Unknown target '${target}'. Use one of: ${SUPPORTED_TARGETS[*]}"
}

validate_permutation() {
    local permutation="$1"
    contains_element "${permutation}" "${SUPPORTED_PERMUTATIONS[@]}" || die "Unknown permutation '${permutation}'. Use one of: ${SUPPORTED_PERMUTATIONS[*]}"
}

compose() {
    docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" "$@"
}

# Side effect: exports the TF_VAR_* overrides that point a stack at its emulator.
export_localstack_tf_vars() {
    local cloud="$1"
    case "${cloud}" in
        aws)
            export TF_VAR_localstack_endpoint="http://localhost:${LOCALSTACK_AWS_PORT:-${DEFAULT_LOCALSTACK_AWS_PORT}}"
            export TF_VAR_localstack_gateway_port="${LOCALSTACK_AWS_PORT:-${DEFAULT_LOCALSTACK_AWS_PORT}}"
            ;;
        azure)
            export TF_VAR_localstack_metadata_host="${LOCALSTACK_AZURE_METADATA_HOST}:${LOCALSTACK_AZURE_PORT:-${DEFAULT_LOCALSTACK_AZURE_PORT}}"
            export TF_VAR_localstack_gateway_port="${LOCALSTACK_AZURE_PORT:-${DEFAULT_LOCALSTACK_AZURE_PORT}}"
            ;;
        *)
            die "No Terraform stack for '${cloud}'"
            ;;
    esac
}

terraform_stack() {
    local cloud="$1"
    shift
    terraform -chdir="${TERRAFORM_ROOT}/${cloud}" "$@"
}

# Side effect: initializes the stack and selects (or creates) the permutation workspace.
prepare_stack() {
    local cloud="$1"
    local permutation="$2"
    terraform_stack "${cloud}" init -input=false -upgrade=false >/dev/null
    terraform_stack "${cloud}" workspace select -or-create=true "$(workspace_for "${permutation}")" >/dev/null
}

workspace_for() {
    local permutation="$1"
    if [ "${permutation}" = "${DEFAULT_PERMUTATION}" ]; then
        echo "default"
    else
        echo "${permutation}"
    fi
}

var_file_for() {
    local permutation="$1"
    echo "${PERMUTATIONS_DIR}/${permutation}.tfvars"
}

# Pure query: prints "<name> <health_url> <resource_url>" lines for the local profile.
local_permutation_urls() {
    local runtime engine port
    for runtime in "${LOCAL_API_RUNTIMES[@]}"; do
        if [ "${runtime}" = "csharp" ]; then
            port="${LOCAL_CSHARP_API_PORT:-${DEFAULT_LOCAL_CSHARP_API_PORT}}"
        else
            port="${LOCAL_KOTLIN_API_PORT:-${DEFAULT_LOCAL_KOTLIN_API_PORT}}"
        fi
        for engine in "${DATABASE_ENGINES[@]}"; do
            echo "local-${runtime}-${engine} http://localhost:${port}/health/${engine} http://localhost:${port}/api/${engine}/v1/salesforce/accounts"
        done
    done
}

# Pure query: prints "<name> <health_url> <resource_url>" lines from Terraform outputs.
cloud_permutation_urls() {
    local cloud="$1"
    terraform_stack "${cloud}" output -json permutations \
        | jq -r 'to_entries[] | "\(.key) \(.value.health_url) \(.value.resource_url)"'
}
