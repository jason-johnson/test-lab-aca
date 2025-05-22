resource "azurerm_servicebus_namespace" "main" {
  name                = provider::namep::namestring("azurerm_servicebus_namespace", local.namep_config)
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"
}

resource "azurerm_servicebus_queue" "fa" {
  name         = "fa_queue"
  namespace_id = azurerm_servicebus_namespace.main.id

  partitioning_enabled = true
}