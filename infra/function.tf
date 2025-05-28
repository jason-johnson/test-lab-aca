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
    "QUEUE_CONNECTION" = "sbmain"
    "QUEUE_NAME" = azurerm_servicebus_queue.fa.name
    "sbmain__fullyQualifiedNamespace" = azurerm_servicebus_namespace.main.endpoint
  }

  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false
}

resource "azurerm_role_assignment" "fun2acr" {
  scope                = data.azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_function_app.main.identity[0].principal_id
}

resource "azurerm_role_assignment" "fa_sb" {
  scope                = azurerm_servicebus_namespace.main.id
  role_definition_name = "Azure Service Bus Data Owner"
  principal_id         = azurerm_linux_function_app.main.identity[0].principal_id
}

# Probably a better method of scaling would be:  https://learn.microsoft.com/en-us/azure/azure-functions/functions-target-based-scaling?tabs=v5%2Ccsharp
resource "azurerm_monitor_autoscale_setting" "fa" {
  name                = "faAutoscaleSetting"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  target_resource_id  = azurerm_service_plan.fa.id

  profile {
    name = "defaultProfile"

    capacity {
      default = 1
      minimum = 1
      maximum = 4
    }

    rule {
      metric_trigger {
        metric_name        = "ActiveMessages"
        metric_resource_id = azurerm_servicebus_namespace.main.id
        metric_namespace   = "microsoft.servicebus/namespaces"
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT10M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 1000
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT10M"
      }
    }
  }
}