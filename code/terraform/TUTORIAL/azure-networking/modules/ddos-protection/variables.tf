# ============================================================================
# Azure DDoS Protection Module - Variables
# ============================================================================
# DDoS Protection protects Azure resources from distributed denial-of-service attacks.
# ============================================================================

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "ddos_protection_plan_name" {
  description = "Name of the DDoS Protection Plan"
  type        = string
}

variable "sku" {
  description = "DDoS Protection Plan SKU. Options: 'Basic' (free, always on) or 'Standard' (paid, advanced features)"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Basic", "Standard"], var.sku)
    error_message = "SKU must be either 'Basic' or 'Standard'."
  }
}

variable "virtual_network_ids" {
  description = "List of Virtual Network IDs to associate with the DDoS Protection Plan"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Map of tags"
  type        = map(string)
  default     = {}
}

