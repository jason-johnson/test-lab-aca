variable "salt" {
  description = "optional salt for use in the name"
  default     = ""
}

variable "location" {
  description = "default location to use if not specified"
  default     = "switzerlandnorth"
}

variable "app_name" {
  description = "Name of the application"
  default     = "testaks"
}