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
  description = "My Client ID"
  default = "bdad61aa-3d0f-416c-ac6b-b99e47e10c13"
}