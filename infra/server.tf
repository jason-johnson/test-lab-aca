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

  node_resource_group = provider::namep::namestring("azurerm_resource_group", local.namep_config, { name = "aksnodes" })

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

resource "azurerm_kubernetes_cluster" "baseline" {
  name                = provider::namep::namestring("azurerm_kubernetes_cluster", local.namep_config, { name = "bl" })
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "aks-costtest-dns"

  default_node_pool {
    name       = "default"
    node_count = 3
    vm_size    = "Standard_D4s_v6"
  }

  node_resource_group = provider::namep::namestring("azurerm_resource_group", local.namep_config, { name = "aksblnodes" })

  identity {
    type = "SystemAssigned"
  }

  # Monitoring Addon (for older provider versions)
  oms_agent {
    log_analytics_workspace_id      = azurerm_log_analytics_workspace.bl.id
    msi_auth_for_monitoring_enabled = true
  }

  network_profile {
    network_plugin = "azure"
  }
}

resource "azurerm_monitor_data_collection_endpoint" "main" {
  name                = provider::namep::namestring("azurerm_monitor_data_collection_endpoint", local.namep_config)
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  kind                = "Linux"

  lifecycle {
    create_before_destroy = true
  }
}

locals {
  streams = [
    "Microsoft-KubePodInventory",
    "Microsoft-ContainerLogV2"
  ]
}

resource "azurerm_monitor_data_collection_rule" "main" {
  name                        = provider::namep::namestring("azurerm_monitor_data_collection_rule", local.namep_config)
  location                    = azurerm_resource_group.main.location
  resource_group_name         = azurerm_resource_group.main.name
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.main.id

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.main.id
      name                  = "aks-destination-log"
    }
  }

  data_flow {
    streams = local.streams

    destinations = ["aks-destination-log"]
  }

  data_sources {
    extension {
      streams        = local.streams
      extension_name = "ContainerInsights"
      extension_json = jsonencode({
        "dataCollectionSettings" : {
          "interval" : "1m",
          "namespaceFilteringMode" : "Exclude",
          "namespaces" : ["kube-system", "gatekeeper-system", "azure-arc"]
          "enableContainerLogV2" : "true"
        }
      })
      name = "ContainerInsightsExtension"
    }
  }

  description = "DCR for Azure Monitor Container Insights"
}

resource "azurerm_monitor_data_collection_rule_association" "main" {
  name                    = "ContainerInsightsExtension"
  target_resource_id      = azurerm_kubernetes_cluster.main.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.main.id
  description             = "Association of container insights data collection rule. Deleting this association will break the data collection for this AKS Cluster."
}

resource "azurerm_role_assignment" "acrpull_be" {
  scope                = data.azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main.identity[0].principal_id
}
