resource "azurerm_resource_group" "main" {
  name     = provider::namep::namestring("azurerm_resource_group", local.namep_config)
  location = var.location
}

data "azurerm_container_registry" "main" {
  name                = var.manual_container_registry
  resource_group_name = var.manual_resource_group
}

resource "azurerm_container_app_environment" "main" {
  name                       = provider::namep::namestring("azurerm_container_app_environment", local.namep_config)
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
}

resource "azurerm_storage_account" "main" {
  name                     = provider::namep::namestring("azurerm_storage_account", local.namep_config)
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}