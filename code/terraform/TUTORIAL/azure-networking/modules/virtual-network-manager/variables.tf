# ============================================================================
# Azure Virtual Network Manager Module - Variables
# ============================================================================
# This module creates an Azure Virtual Network Manager with network groups,
# connectivity configurations, security admin rules, and routing configurations.
#
# Virtual Network Manager provides centralized network governance across
# multiple subscriptions and regions.
# ============================================================================

# ----------------------------------------------------------------------------
# Resource Group Configuration
# ----------------------------------------------------------------------------
variable "resource_group_name" {
  description = "Name of the resource group where the Network Manager will be created. Leave empty to create a new resource group."
  type        = string
  default     = ""
}


variable "project_name" {
  description = "Project name used for resource naming (required if resource_group_name is empty)"
  type        = string
  default     = ""
}

variable "application_name" {
  description = "Application name used for resource naming (optional, defaults to 'vnm' if empty)"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment name (e.g., 'dev', 'staging', 'prod') - required if resource_group_name is empty"
  type        = string
  default     = ""
}

variable "location" {
  description = "Azure region where resources will be created (e.g., 'eastus', 'westeurope')"
  type        = string
}

# ----------------------------------------------------------------------------
# Network Manager Configuration
# ----------------------------------------------------------------------------
variable "network_manager_name" {
  description = "Name of the Network Manager instance"
  type        = string
}

# ----------------------------------------------------------------------------
# Scope Configuration
# ----------------------------------------------------------------------------
variable "scope_management_group_ids" {
  description = "List of Management Group IDs that the Network Manager will manage. Use this for enterprise-wide governance."
  type        = list(string)
  default     = null

  validation {
    condition     = var.scope_management_group_ids == null || length(var.scope_management_group_ids) > 0
    error_message = "If scope_management_group_ids is provided, it must contain at least one Management Group ID."
  }
}

variable "scope_subscription_ids" {
  description = "List of subscription IDs that the Network Manager will manage. Use this for subscription-specific management."
  type        = list(string)
  default     = null

  validation {
    condition     = var.scope_subscription_ids == null || length(var.scope_subscription_ids) > 0
    error_message = "If scope_subscription_ids is provided, it must contain at least one Subscription ID."
  }
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

variable "description" {
  description = "Description of the Network Manager instance"
  type        = string
  default     = "Azure Virtual Network Manager for centralized network governance"
}

variable "tags" {
  description = "Map of tags to assign to the Network Manager"
  type        = map(string)
  default     = {}
}

# ----------------------------------------------------------------------------
# Network Groups
# ----------------------------------------------------------------------------
variable "network_groups" {
  description = "Map of network groups to create. Each group can have static or dynamic membership"
  type = map(object({
    description            = optional(string)
    static_member_vnet_ids = optional(list(string), [])
    # Note: Dynamic membership via Azure Policy is configured separately
  }))
  default = {}
}

# ----------------------------------------------------------------------------
# Connectivity Configurations
# ----------------------------------------------------------------------------
variable "connectivity_configurations" {
  description = "Map of connectivity configurations (hub-and-spoke or mesh)"
  type = map(object({
    topology                        = string # "HubAndSpoke" or "Mesh"
    network_group_names             = list(string)
    group_connectivity              = optional(string, "None") # "None" or "DirectlyConnected"
    use_hub_gateway                 = optional(bool, false)    # If true, spokes can use hub's VPN/ExpressRoute gateway
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
# Security Admin Configurations
# ----------------------------------------------------------------------------
variable "security_admin_configurations" {
  description = "Map of security admin configurations"
  type = map(object({
    network_group_names = list(string)
    description         = optional(string)
  }))
  default = {}
}

# ----------------------------------------------------------------------------
# Security Admin Rule Collections
# ----------------------------------------------------------------------------
variable "security_admin_rule_collections" {
  description = "Map of security admin rule collections"
  type = map(object({
    security_admin_configuration_name = string
    network_group_names               = list(string)
    description                       = optional(string)
  }))
  default = {}
}

# ----------------------------------------------------------------------------
# Security Admin Rules
# ----------------------------------------------------------------------------
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
# Routing Configurations
# ----------------------------------------------------------------------------
variable "routing_configurations" {
  description = "Map of routing configurations"
  type = map(object({
    network_group_names = list(string)
    description         = optional(string)
  }))
  default = {}
}

# ----------------------------------------------------------------------------
# Routing Rule Collections
# ----------------------------------------------------------------------------
variable "routing_rule_collections" {
  description = "Map of routing rule collections. Groups related routing rules together."
  type = map(object({
    routing_configuration_name = string
    network_group_names        = list(string)
    description                = optional(string)
  }))
  default = {}
}

# ----------------------------------------------------------------------------
# Routing Rules
# ----------------------------------------------------------------------------
variable "routing_rules" {
  description = "Map of routing rules. Define how traffic should be routed (e.g., next-hop to firewall)."
  type = map(object({
    rule_collection_name = string
    description          = optional(string)
    destination_type     = string           # "AddressPrefix" or "ServiceTag"
    destination_address  = string           # e.g., "0.0.0.0/0" or "Internet"
    next_hop_type        = string           # "VirtualAppliance", "Internet", "VnetLocal", "VnetPeering", "None"
    next_hop_address     = optional(string) # IP address for VirtualAppliance, null for others
  }))
  default = {}
}

# ----------------------------------------------------------------------------
# Deployments
# ----------------------------------------------------------------------------
variable "deployments" {
  description = "Map of configuration deployments to regions. Configurations do not take effect until deployed."
  type = map(object({
    location          = string
    scope_access      = string # "Connectivity", "SecurityAdmin", "Routing"
    configuration_ids = list(string)
  }))
  default = {}
}

