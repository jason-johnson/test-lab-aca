resource "azurerm_storage_account" "fa" {
  name                     = provider::namep::namestring("azurerm_storage_account", local.namep_config, { name = "fa" })
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "fa" {
  name                = provider::namep::namestring("azurerm_app_service_plan", local.namep_config, { name = "fa" })
  resource_group_name = azurerm_resource_group.main.name
  location            = "westeurope"
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_function_app" "main" {
  name                = provider::namep::namestring("azurerm_function_app", local.namep_config)
  resource_group_name = azurerm_resource_group.main.name
  location            = "westeurope"

  storage_account_name       = azurerm_storage_account.fa.name
  storage_account_access_key = azurerm_storage_account.fa.primary_access_key
  service_plan_id            = azurerm_service_plan.fa.id

  site_config {}
}
