#!/usr/bin/env bash
# ============================================================================
# Mint a LOCAL-DEVELOPMENT-ONLY HS256 JWT for the CRM APIs (C# and Kotlin).
#   ./crm-infra/scripts/dev-token.sh <admin|user> [ttl-seconds]
#
# Roles (JWT `roles` claim): anonymous = read-only (GET), user = create/update,
# admin = create/update/delete. Prints the bare token on stdout:
#   curl -H "Authorization: Bearer $(./crm-infra/scripts/dev-token.sh admin)" ...
#
# Overrides (defaults match the dev settings of both APIs; never use in production):
#   CRM_JWT_SECRET  CRM_JWT_ISSUER  CRM_JWT_AUDIENCE  CRM_JWT_SUBJECT
# ============================================================================
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

readonly SUPPORTED_ROLES=("admin" "user")
readonly DEFAULT_TTL_SECONDS=3600
readonly DEFAULT_JWT_SECRET="LocalStackCRMReferenceArchitectureJwtSigningSecretKey2026!"
readonly DEFAULT_JWT_ISSUER="https://auth.localstack.local"
readonly DEFAULT_JWT_AUDIENCE="crm-api"
readonly DEFAULT_JWT_SUBJECT="dev-user"
readonly ROLE="${1:-}"
readonly TTL_SECONDS="${2:-${DEFAULT_TTL_SECONDS}}"
readonly JWT_SECRET="${CRM_JWT_SECRET:-${DEFAULT_JWT_SECRET}}"
readonly JWT_ISSUER="${CRM_JWT_ISSUER:-${DEFAULT_JWT_ISSUER}}"
readonly JWT_AUDIENCE="${CRM_JWT_AUDIENCE:-${DEFAULT_JWT_AUDIENCE}}"
readonly JWT_SUBJECT="${CRM_JWT_SUBJECT:-${DEFAULT_JWT_SUBJECT}}"

[ -n "${ROLE}" ] || die "Usage: $(basename "$0") <admin|user> [ttl-seconds]"
contains_element "${ROLE}" "${SUPPORTED_ROLES[@]}" || die "Unknown role '${ROLE}'. Use one of: ${SUPPORTED_ROLES[*]}"
[[ "${TTL_SECONDS}" =~ ^[0-9]+$ ]] || die "ttl-seconds must be a non-negative integer."
require_command openssl "Install OpenSSL."

# Pure: base64url-encodes stdin without padding.
base64url() {
    openssl base64 -A | tr '+/' '-_' | tr -d '='
}

readonly ISSUED_AT="$(date +%s)"
readonly EXPIRES_AT="$((ISSUED_AT + TTL_SECONDS))"
readonly HEADER='{"alg":"HS256","typ":"JWT"}'
readonly PAYLOAD="{\"sub\":\"${JWT_SUBJECT}\",\"iss\":\"${JWT_ISSUER}\",\"aud\":\"${JWT_AUDIENCE}\",\"iat\":${ISSUED_AT},\"nbf\":${ISSUED_AT},\"exp\":${EXPIRES_AT},\"roles\":[\"${ROLE}\"]}"

readonly SIGNING_INPUT="$(printf '%s' "${HEADER}" | base64url).$(printf '%s' "${PAYLOAD}" | base64url)"
readonly SIGNATURE="$(printf '%s' "${SIGNING_INPUT}" | openssl dgst -sha256 -hmac "${JWT_SECRET}" -binary | base64url)"

printf '%s.%s\n' "${SIGNING_INPUT}" "${SIGNATURE}"
