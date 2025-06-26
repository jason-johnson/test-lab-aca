resource "azurerm_resource_group" "aks" {
  name     = provider::namep::namestring("azurerm_resource_group", local.namep_config, { name = "aksnodes" })
  location = var.location
}

resource "azurerm_log_analytics_solution" "main" {
  solution_name         = "Containers"
  workspace_resource_id = azurerm_log_analytics_workspace.main.id
  workspace_name        = azurerm_log_analytics_workspace.main.name
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/Containers"
  }
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

  node_resource_group = azurerm_resource_group.aks.name

  identity {
    type = "SystemAssigned"
  }

  # Monitoring Addon (for older provider versions)
  oms_agent {
    log_analytics_workspace_id      = azurerm_log_analytics_workspace.main.id
    msi_auth_for_monitoring_enabled = true
  }

  network_profile {
    network_plugin = "azure"
  }
}

resource "azurerm_role_assignment" "acrpull_be" {
  scope                = data.azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main.identity[0].principal_id
}
