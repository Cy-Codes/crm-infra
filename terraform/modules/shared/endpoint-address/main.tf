# ============================================================================
# Endpoint Address Parser (pure helper)
# Normalizes "host" or "host:port" endpoint strings. Emulators such as
# LocalStack for Azure embed a non-default port in the reported FQDN
# (e.g. myserver.postgresql.azure.localhost.localstack.cloud:4511).
# ============================================================================

locals {
  parts = split(":", var.address)
  host  = local.parts[0]
  port  = length(local.parts) > 1 ? tonumber(local.parts[1]) : var.default_port
}
