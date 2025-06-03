output "fully_qualified_namespace" {
    value = replace(replace(azurerm_servicebus_namespace.main.endpoint, "https://", ""), ":443/", "")  
}

output "aca_queue_name" {
    value = azurerm_servicebus_queue.aca.name
}

output "fa_queue_name" {
    value = azurerm_servicebus_queue.fa.name
}