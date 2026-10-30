# ============================================================================
# Azure Virtual Network Manager Example - Variables
# ============================================================================
# This file defines all input variables for the Virtual Network Manager example.
# Use terraform.tfvars to provide values for these variables.
# ============================================================================

# ----------------------------------------------------------------------------
# Azure Configuration
# ----------------------------------------------------------------------------
variable "location" {
  description = "Azure region where resources will be created"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Name of the resource group for Network Manager. Leave empty to auto-create."
  type        = string
  default     = ""
}

variable "project_name" {
  description = "Project name used for resource naming (required if resource_group_name is empty)"
  type        = string
  default     = ""
}

variable "application_name" {
  description = "Application name used for resource naming"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment name (e.g., 'dev', 'staging', 'prod')"
  type        = string
  default     = ""
}

# ----------------------------------------------------------------------------
# Network Manager Configuration
# ----------------------------------------------------------------------------
variable "network_manager_name" {
  description = "Name of the Network Manager instance"
  type        = string
}

variable "network_manager_description" {
  description = "Description of the Network Manager instance"
  type        = string
  default     = "Network Manager for centralized network governance"
}

# ----------------------------------------------------------------------------
# Scope Configuration
# ----------------------------------------------------------------------------
variable "scope_management_group_ids" {
  description = "List of Management Group IDs for enterprise-wide governance (optional)"
  type        = list(string)
  default     = []
}

variable "scope_subscription_ids" {
  description = "List of subscription IDs for subscription-specific management (optional)"
  type        = list(string)
  default     = []
}

variable "scope_accesses" {
  description = "List of scope accesses. Valid values: 'Connectivity', 'SecurityAdmin', 'Routing'"
  type        = list(string)
  default     = ["Connectivity", "SecurityAdmin", "Routing"]

  validation {
    condition = alltrue([
      for access in var.scope_accesses : contains(["Connectivity", "SecurityAdmin", "Routing"], access)
    ])
    error_message = "Scope accesses must be one or more of: Connectivity, SecurityAdmin, Routing"
  }
}

# ----------------------------------------------------------------------------
# Network Groups Configuration
# ----------------------------------------------------------------------------
variable "network_groups" {
  description = "Map of network groups with their VNet members"
  type = map(object({
    description            = optional(string)
    static_member_vnet_ids = optional(list(string), [])
  }))
  default = {}
}

# ----------------------------------------------------------------------------
# Connectivity Configuration
# ----------------------------------------------------------------------------
variable "connectivity_configurations" {
  description = "Map of connectivity configurations (hub-and-spoke or mesh)"
  type = map(object({
    topology                        = string # "HubAndSpoke" or "Mesh"
    network_group_names             = list(string)
    group_connectivity              = optional(string, "None") # "None" or "DirectlyConnected"
    use_hub_gateway                 = optional(bool, false)
    delete_existing_peering_enabled = optional(bool, false)
    description                     = optional(string)
    hub = optional(object({
      resource_id   = string
      resource_type = string # "Microsoft.Network/virtualNetworks"
    }))
  }))
  default = {}
}

# ----------------------------------------------------------------------------
# Security Admin Configuration
# ----------------------------------------------------------------------------
variable "security_admin_configurations" {
  description = "Map of security admin configurations"
  type = map(object({
    network_group_names = list(string)
    description         = optional(string)
  }))
  default = {}
}

variable "security_admin_rule_collections" {
  description = "Map of security admin rule collections"
  type = map(object({
    security_admin_configuration_name = string
    network_group_names               = list(string)
    description                       = optional(string)
  }))
  default = {}
}

variable "security_admin_rules" {
  description = "Map of security admin rules"
  type = map(object({
    rule_collection_name            = string
    priority                        = number
    direction                       = string # "Inbound" or "Outbound"
    action                          = string # "Allow" or "Deny"
    protocol                        = string # "Tcp", "Udp", "Icmp", "Esp", "Any", "Ah"
    source_address_prefix_type      = string # "IPPrefix", "ServiceTag", "Default"
    source_address_prefix           = optional(string)
    destination_address_prefix_type = string
    destination_address_prefix      = optional(string)
    source_port_ranges              = optional(list(string), [])
    destination_port_ranges         = optional(list(string), [])
    description                     = optional(string)
  }))
  default = {}
}

# ----------------------------------------------------------------------------
# Routing Configuration
# ----------------------------------------------------------------------------
variable "routing_configurations" {
  description = "Map of routing configurations"
  type = map(object({
    network_group_names = list(string)
    description         = optional(string)
  }))
  default = {}
}

variable "routing_rule_collections" {
  description = "Map of routing rule collections"
  type = map(object({
    routing_configuration_name = string
    network_group_names        = list(string)
    description                = optional(string)
  }))
  default = {}
}

variable "routing_rules" {
  description = "Map of routing rules"
  type = map(object({
    rule_collection_name = string
    description          = optional(string)
    destination_type     = string # "AddressPrefix" or "ServiceTag"
    destination_address  = string
    next_hop_type        = string # "VirtualAppliance", "Internet", "VnetLocal", "VnetPeering", "None"
    next_hop_address     = optional(string)
  }))
  default = {}
}

# ----------------------------------------------------------------------------
# Deployment Configuration
# ----------------------------------------------------------------------------
variable "deployments" {
  description = "Map of configuration deployments to regions"
  type = map(object({
    location          = string
    scope_access      = string # "Connectivity", "SecurityAdmin", "Routing"
    configuration_ids = list(string)
  }))
  default = {}
}

# ----------------------------------------------------------------------------
# Tags
# ----------------------------------------------------------------------------
variable "tags" {
  description = "Map of tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "Example"
    ManagedBy   = "Terraform"
    Purpose     = "Network Manager Demo"
  }
}

