resource "azurerm_resource_group" "main" {
  name     = provider::namep::namestring("azurerm_resource_group", local.namep_config)
  location = var.location
}

data "azurerm_container_registry" "main" {
  name                = "acrjbjmcap1"
  resource_group_name = "rg-manual"
}