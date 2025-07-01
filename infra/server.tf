resource "azurerm_user_assigned_identity" "aks_main" {
  name                = provider::namep::namestring("azurerm_user_assigned_identity", local.namep_config, { name = "aks" })
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
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

  node_resource_group = provider::namep::namestring("azurerm_resource_group", local.namep_config, { name = "aksnodes" })

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks_main.id]
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
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks_main.id]
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

resource "azurerm_monitor_data_collection_endpoint" "baseline" {
  name                = provider::namep::namestring("azurerm_monitor_data_collection_endpoint", local.namep_config, { name = "bl" })
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

  # Streams for comprehensive logging (no exclusions)
  all_streams = [
    "Microsoft-KubePodInventory",
    "Microsoft-ContainerLogV2",
    "Microsoft-KubeEvents",
    "Microsoft-KubeNodeInventory",
    "Microsoft-KubeServices",
    "Microsoft-InsightsMetrics",
    "Microsoft-ContainerInventory",
    "Microsoft-ContainerNodeInventory"
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
          "namespaces" : ["kube-system", "gatekeeper-system", "azure-arc"],
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

# Comprehensive DCR for baseline cluster (logs everything)
resource "azurerm_monitor_data_collection_rule" "baseline" {
  name                        = provider::namep::namestring("azurerm_monitor_data_collection_rule", local.namep_config, { name = "bl" })
  location                    = azurerm_resource_group.main.location
  resource_group_name         = azurerm_resource_group.main.name
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.baseline.id

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.bl.id
      name                  = "aks-baseline-destination-log"
    }
  }

  data_flow {
    streams      = local.all_streams
    destinations = ["aks-baseline-destination-log"]
  }

  data_sources {
    extension {
      streams        = local.all_streams
      extension_name = "ContainerInsights"
      extension_json = jsonencode({
        "dataCollectionSettings" : {
          "interval" : "1m",
          "namespaceFilteringMode" : "Off",
          "enableContainerLogV2" : "true",
          "streams" : [
            "Microsoft-KubePodInventory",
            "Microsoft-ContainerLogV2",
            "Microsoft-KubeEvents",
            "Microsoft-KubeNodeInventory",
            "Microsoft-KubeServices",
            "Microsoft-InsightsMetrics",
            "Microsoft-ContainerInventory",
            "Microsoft-ContainerNodeInventory"
          ]
        }
      })
      name = "ContainerInsightsExtensionBaseline"
    }
  }

  description = "DCR for Azure Monitor Container Insights - Baseline (logs everything)"
}

resource "azurerm_monitor_data_collection_rule_association" "baseline" {
  name                    = "ContainerInsightsExtensionBaseline"
  target_resource_id      = azurerm_kubernetes_cluster.baseline.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.baseline.id
  description             = "Association of comprehensive data collection rule for baseline cluster. Logs all namespaces and data types."
}

resource "azurerm_role_assignment" "acrpull_kubelet" {
  scope                = data.azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

# Role assignment for baseline cluster kubelet identity to pull images from ACR
resource "azurerm_role_assignment" "acrpull_kubelet_baseline" {
  scope                = data.azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.baseline.kubelet_identity[0].object_id
}
