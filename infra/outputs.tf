output "client_certificate" {
  value     = azurerm_kubernetes_cluster.main.kube_config[0].client_certificate
  sensitive = true
}

output "kube_config" {
  value = split("\n", azurerm_kubernetes_cluster.main.kube_config_raw)[0]

  sensitive = true
}