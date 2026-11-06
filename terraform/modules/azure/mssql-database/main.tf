# ============================================================================
# Azure SQL Database (logical server + database)
# Azure counterpart of Amazon RDS for SQL Server in the AWS stack.
# ============================================================================

resource "azurerm_mssql_server" "this" {
  name                          = var.server_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  version                       = var.server_version
  administrator_login           = var.administrator_login
  administrator_login_password  = var.administrator_password
  minimum_tls_version           = var.minimum_tls_version
  public_network_access_enabled = true
  tags                          = var.tags
}

resource "azurerm_mssql_database" "this" {
  name        = var.database_name
  server_id   = azurerm_mssql_server.this.id
  sku_name    = var.sku_name
  max_size_gb = var.max_size_gb
  tags        = var.tags
}

resource "azurerm_mssql_firewall_rule" "this" {
  for_each = var.firewall_rules

  name             = each.key
  server_id        = azurerm_mssql_server.this.id
  start_ip_address = each.value.start_ip_address
  end_ip_address   = each.value.end_ip_address
}

module "endpoint" {
  source = "../../shared/endpoint-address"

  address      = azurerm_mssql_server.this.fully_qualified_domain_name
  default_port = var.default_port
}
