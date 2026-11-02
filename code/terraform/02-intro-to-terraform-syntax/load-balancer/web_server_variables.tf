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
