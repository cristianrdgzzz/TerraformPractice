# ============================================================================
# Azure Virtual WAN Module - Variables
# ============================================================================
# Virtual WAN is a networking service that brings together many networking,
# security, and routing functionalities into a single operational interface.
# ============================================================================

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "virtual_wan_name" {
  description = "Name of the Virtual WAN"
  type        = string
}

variable "allow_branch_to_branch_traffic" {
  description = "Allow branch-to-branch traffic (spoke-to-spoke)"
  type        = bool
  default     = true
}

variable "disable_vpn_encryption" {
  description = "Disable VPN encryption (not recommended)"
  type        = bool
  default     = false
}

variable "office365_local_breakout_category" {
  description = "Office 365 local breakout category. Options: 'None', 'Optimize', 'Allow', 'Default'"
  type        = string
  default     = "None"

  validation {
    condition     = contains(["None", "Optimize", "Allow", "Default"], var.office365_local_breakout_category)
    error_message = "Office 365 local breakout category must be one of: None, Optimize, Allow, Default."
  }
}

variable "type" {
  description = "Virtual WAN type. Options: 'Basic' or 'Standard'"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Basic", "Standard"], var.type)
    error_message = "Virtual WAN type must be either 'Basic' or 'Standard'."
  }
}

variable "virtual_hubs" {
  description = <<-EOT
    Map of virtual hubs to create.
    Virtual hubs are the central connectivity points in Virtual WAN.
    
    Example:
    virtual_hubs = {
      "hub-eastus" = {
        name                = "vhub-eastus"
        address_prefix      = "10.1.0.0/24"
        sku                 = "Standard"
        hub_routing_preference = "ExpressRoute"  # "ExpressRoute", "VPN", "ASPath"
      }
    }
  EOT
  type = map(object({
    name                   = string
    address_prefix         = string
    sku                    = string # "Basic" or "Standard"
    hub_routing_preference = optional(string, "ExpressRoute")
    tags                   = optional(map(string), {})
  }))
  default = {}
}

variable "tags" {
  description = "Map of tags"
  type        = map(string)
  default     = {}
}

