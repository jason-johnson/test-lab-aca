resource "azurerm_user_assigned_identity" "backend" {
  name                = provider::namep::namestring("azurerm_user_assigned_identity", local.namep_config, { name = "backend" })
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = provider::namep::namestring("azurerm_kubernetes_cluster", local.namep_config)
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "aks-costtest-dns"

  default_node_pool {
    name       = "default"
    node_count = 3
    vm_size    = "Standard_D4s_v6"
  }

  identity {
    type = "SystemAssigned"
  }

  # Monitoring Addon (for older provider versions)
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  network_profile {
    network_plugin = "azure"
  }
}
resource "azurerm_role_assignment" "acrpull_be" {
  scope                = data.azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.backend.principal_id
}

resource "azurerm_key_vault_secret" "backend_secret" {
  name         = "backend-entra-app-secret"
  key_vault_id = azurerm_key_vault.main.id
  value        = azuread_application_password.backend.value

  depends_on = [azurerm_role_assignment.managed_admin, azurerm_role_assignment.managed_secrets]
}