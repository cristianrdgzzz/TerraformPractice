# ============================================================================
# Azure Bastion Module - Variables
# ============================================================================
# Azure Bastion provides secure RDP/SSH access to VMs without public IPs.
# It's a fully managed PaaS service that provides secure connectivity.
#
# Key Features:
# - Browser-based RDP/SSH access
# - No public IPs required on VMs
# - No VPN required
# - All traffic encrypted (HTTPS)
# - NSG integration
# - Native Azure Portal integration
# ============================================================================

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "bastion_name" {
  description = "Name of the Azure Bastion host"
  type        = string
}

variable "bastion_subnet_id" {
  description = "Subnet ID for Azure Bastion. Must be named 'AzureBastionSubnet' and have /26 or larger CIDR (minimum /27)."
  type        = string
}

variable "public_ip_address_id" {
  description = "Public IP address ID for Azure Bastion. Required for internet access."
  type        = string
}

variable "sku" {
  description = "SKU of Azure Bastion. Options: 'Basic' or 'Standard'"
  type        = string
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard"], var.sku)
    error_message = "SKU must be either 'Basic' or 'Standard'."
  }
}

variable "scale_units" {
  description = "Number of scale units (2-50). Only for Standard SKU. Default is 2."
  type        = number
  default     = 2

  validation {
    condition     = var.scale_units >= 2 && var.scale_units <= 50
    error_message = "Scale units must be between 2 and 50."
  }
}

variable "copy_paste_enabled" {
  description = "Enable copy/paste functionality. Default is true."
  type        = bool
  default     = true
}

variable "file_copy_enabled" {
  description = "Enable file copy functionality. Only for Standard SKU. Default is false."
  type        = bool
  default     = false
}

variable "ip_connect_enabled" {
  description = "Enable IP connect functionality. Only for Standard SKU. Default is false."
  type        = bool
  default     = false
}

variable "shareable_link_enabled" {
  description = "Enable shareable link functionality. Only for Standard SKU. Default is false."
  type        = bool
  default     = false
}

variable "tunneling_enabled" {
  description = "Enable native client support (RDP/SSH clients). Only for Standard SKU. Default is false."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Map of tags"
  type        = map(string)
  default     = {}
}

