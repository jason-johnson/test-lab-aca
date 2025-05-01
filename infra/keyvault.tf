resource "azurerm_key_vault" "main" {
  name                       = provider::namep::namestring("azurerm_key_vault", local.namep_config)
  location                   = var.location
  resource_group_name        = azurerm_resource_group.main.name
  sku_name                   = "standard"
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  enable_rbac_authorization  = true
}

resource "azurerm_role_assignment" "managed_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "managed_secrets" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "jason" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = "f69e86b7-ec56-4d0b-9dbd-2505849bb87c"
}

resource "azurerm_role_assignment" "kv_backend" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_container_app.backend.identity.0.principal_id
}