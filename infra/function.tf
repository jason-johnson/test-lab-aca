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
  sku_name            = "P0v3"
}

resource "azurerm_linux_function_app" "main" {
  name                = provider::namep::namestring("azurerm_function_app", local.namep_config)
  resource_group_name = azurerm_resource_group.main.name
  location            = "westeurope"

  storage_account_name       = azurerm_storage_account.fa.name
  storage_account_access_key = azurerm_storage_account.fa.primary_access_key
  service_plan_id            = azurerm_service_plan.fa.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on = true

    application_insights_connection_string  = azurerm_application_insights.main.connection_string
    application_insights_key                = azurerm_application_insights.main.instrumentation_key
    container_registry_use_managed_identity = true
    application_stack {
        docker {
            image_name = "acalab/server"
            registry_url = data.azurerm_container_registry.main.login_server
            image_tag = "latest"
        }
    }
  }

  app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
    "QUEUE_CONNECTION" = azurerm_servicebus_namespace.main.default_primary_connection_string
    "QUEUE_NAME" = azurerm_servicebus_queue.fa.name
  }

  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false
}

resource "azurerm_role_assignment" "fun2acr" {
  scope                = data.azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_function_app.main.identity[0].principal_id
}