variable "salt" {
  description = "optional salt for use in the name"
  default = ""
}

variable "location" {
  description = "default location to use if not specified"
  default = "switzerlandnorth"  
}

variable "app_name" {
  description = "Name of the application"
  default = "lab"
}

variable "me_client_id" {
  description = "Client ID of user running the lab"
}

variable "manual_resource_group" {
  description = "Name of the manual resource group"
}

variable "manual_container_registry" {
  description = "Name of the manual container registry"
}