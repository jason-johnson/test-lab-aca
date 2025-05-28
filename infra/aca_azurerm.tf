resource "azurerm_storage_account" "aca" {
  name                     = provider::namep::namestring("azurerm_storage_account", local.namep_config, { name = "aca" })
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_user_assigned_identity" "azrmaca" {
  name                = provider::namep::namestring("azurerm_user_assigned_identity", local.namep_config, { name = "azrmaca" })
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

locals {
  azrmaca_app_name = provider::namep::namestring("azurerm_container_app", local.namep_config, { name = "azrmaca" })
}

resource "azurerm_container_app" "azrmaca" {
  name                         = local.azrmaca_app_name
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  identity {
    type         = "SystemAssigned, UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.azrmaca.id]
  }

  registry {
    server   = data.azurerm_container_registry.main.login_server
    identity = azurerm_user_assigned_identity.azrmaca.id
  }

  template {
    max_replicas = 4
    min_replicas = 1

    container {
      name   = "azrmaca"
      image  = "${data.azurerm_container_registry.main.login_server}/acalab/server:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "QUEUE_NAME"
        value = azurerm_servicebus_queue.aca.name
      }

      env {
        name  = "QUEUE_CONNECTION"
        value = "sbmain"
      }

      env {
        name  = "sbmain__fullyQualifiedNamespace"
        value = azurerm_servicebus_namespace.main.endpoint
      }

      env {
        name  = "AzureWebJobsStorage"
        value = azurerm_storage_account.aca.primary_connection_string
      }

      startup_probe {
        transport = "HTTP"
        path      = "/api/health_probe"
        port      = 80
      }

      liveness_probe {
        transport = "HTTP"
        path      = "/api/health_probe"
        port      = 80
      }

      readiness_probe {
        transport = "HTTP"
        path      = "/api/health_probe"
        port      = 80
      }
    }

    # Manual work required to turn on MI auth, see: https://github.com/hashicorp/terraform-provider-azurerm/issues/26570
    custom_scale_rule {
      name             = "servicebus-queue-length"
      custom_rule_type = "azure-servicebus"
      metadata = {
        "queueName"    = azurerm_servicebus_queue.aca.name
        "namespace"    = azurerm_servicebus_namespace.main.name
        "messageCount" = "1000"
      }
    }
  }

  ingress {
    external_enabled = true # for testing only
    target_port      = 80

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }

    ip_security_restriction {
      action           = "Allow"
      ip_address_range = "85.6.236.222/32"
      name             = "Home network"
    }
  }

  depends_on = [azurerm_role_assignment.acrpull_be]
}

resource "azapi_update_resource" "container_app_scale_update" {
  type                   = "Microsoft.App/containerApps@2025-01-01"
  resource_id            = azurerm_container_app.azrmaca.id
  response_export_values = ["*"]

  body = {
    properties = {
      template = {
        scale = {
          cooldownPeriod = 1800

          rules = [
            {
              custom = {
                identity = azurerm_user_assigned_identity.azrmaca.id
              }
            }
          ]
        }
      }
    }
  }

  depends_on = [azurerm_container_app.azrmaca, azurerm_user_assigned_identity.azrmaca]
}

resource "azurerm_role_assignment" "acrpull_be" {
  scope                = data.azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.azrmaca.principal_id
}

resource "azurerm_role_assignment" "aca_sb" {
  scope                = azurerm_servicebus_namespace.main.id
  role_definition_name = "Azure Service Bus Data Owner"
  principal_id         = azurerm_user_assigned_identity.azrmaca.principal_id
}

resource "azurerm_role_assignment" "aca_sb_si" {
  scope                = azurerm_servicebus_namespace.main.id
  role_definition_name = "Azure Service Bus Data Owner"
  principal_id         = azurerm_container_app.azrmaca.identity[0].principal_id
}
