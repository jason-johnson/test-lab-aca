output "fully_qualified_namespace" {
    value = replace(replace(azurerm_servicebus_namespace.main.endpoint, "https://", ""), ":443/", "")  
}

output "queue_name" {
    value = azurerm_servicebus_queue.aca.name
}