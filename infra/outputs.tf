output "fully_qualified_namespace" {
    value = azurerm_servicebus_namespace.main.endpoint  
}

output "queue_name" {
    value = azurerm_servicebus_queue.aca.name
}