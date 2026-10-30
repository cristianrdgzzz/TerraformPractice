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

variable "vm_size" {
  description = "Tamaño de cada máquina virtual"
  type        = string
  default     = "Standard_D2s_v7"
}

variable "instance_count" {
  description = "Número inicial y mínimo de máquinas"
  type        = number
  default     = 2

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 10
    error_message = "instance_count debe estar entre 1 y 10."
  }
}

variable "max_instance_count" {
  description = "Número máximo de máquinas al escalar"
  type        = number
  default     = 5

  validation {
    condition     = var.max_instance_count >= var.instance_count
    error_message = "max_instance_count debe ser mayor o igual que instance_count."
  }
}