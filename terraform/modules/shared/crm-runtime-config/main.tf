# ============================================================================
# CRM API Runtime Configuration Contract (pure, cloud-agnostic)
# Translates provider-neutral database endpoints into the exact environment
# variables each API runtime expects. Compute modules on every cloud consume
# the resulting `environment` (plain) and `secrets` (sensitive) maps verbatim,
# so moving an API between providers never changes its configuration shape.
#
# Both runtimes receive the SAME ADO.NET-style connection string per engine;
# only the environment variable spelling differs:
#   csharp -> ConnectionStrings__CRMDatabaseMS  (.NET '__' section separator)
#   kotlin -> CONNECTIONSTRINGS_CRMDATABASEMS   (Spring relaxed binding of
#             ConnectionStrings.CRMDatabaseMS, see DbConnectionFactory.kt)
# ============================================================================

locals {
  npgsql_ssl_modes = {
    disable = "Disable"
    prefer  = "Prefer"
    require = "Require"
  }

  # Secret environment variable names per runtime and engine. Kept separate from
  # the (sensitive) values so callers can iterate over them with for_each.
  secret_keys = {
    csharp = {
      ms = "ConnectionStrings__CRMDatabaseMS"
      pg = "ConnectionStrings__CRMDatabasePG"
    }
    kotlin = {
      ms = "CONNECTIONSTRINGS_CRMDATABASEMS"
      pg = "CONNECTIONSTRINGS_CRMDATABASEPG"
    }
  }

  engines = sort(keys(var.databases))

  connection_strings = {
    ms = try(join(";", [
      "Server=${var.databases.ms.host},${var.databases.ms.port}",
      "Database=${var.databases.ms.database_name}",
      "User Id=${var.databases.ms.username}",
      "Password=${var.databases.ms.password}",
      "Encrypt=True",
      "TrustServerCertificate=True",
      "",
    ]), null)
    pg = try(join(";", [
      "Host=${var.databases.pg.host}",
      "Port=${var.databases.pg.port}",
      "Database=${var.databases.pg.database_name}",
      "Username=${var.databases.pg.username}",
      "Password=${var.databases.pg.password}",
      "SSL Mode=${local.npgsql_ssl_modes[var.databases.pg.ssl_mode]}",
      "",
    ]), null)
  }

  environment = {
    csharp = {}
    kotlin = {}
  }

  secrets = {
    for runtime, keys_by_engine in local.secret_keys : runtime => {
      for engine in local.engines : keys_by_engine[engine] => local.connection_strings[engine]
    }
  }

  secret_names = {
    for runtime, keys_by_engine in local.secret_keys : runtime => [for engine in local.engines : keys_by_engine[engine]]
  }
}
