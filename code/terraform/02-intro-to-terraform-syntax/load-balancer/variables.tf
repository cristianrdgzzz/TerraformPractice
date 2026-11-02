variable "resource_group_name" {
  description = "Nombre del grupo de recursos de Azure"
  type        = string
  default     = "rg-web-cluster"
}

variable "location" {
  description = "Región de Azure"
  type        = string
  default     = "westus2"
}

variable "environment" {
  description = "Nombre del entorno, usado también para formar nombres"
  type        = string
  default     = "production"
}

variable "vnet_address_space" {
  description = "Rango de direcciones de la red virtual"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_address_prefixes" {
  description = "Rango de direcciones de la subred"
  type        = string
  default     = "10.0.1.0/24"
}

variable "server_port" {
  description = "Puerto HTTP en el que escucha la aplicación de cada máquina"
  type        = number
  default     = 80

  validation {
    condition     = var.server_port >= 1 && var.server_port <= 65535
    error_message = "server_port debe estar entre 1 y 65535."
  }
}