# ============================================================================
# Virtual Network Module - Variables
# ============================================================================
# This module creates an Azure Virtual Network (VNet) with subnets, 
# Network Security Groups (NSGs), and route tables.
#
# Virtual Networks are the fundamental building blocks of Azure networking.
# They provide isolation and segmentation for your Azure resources.
# ============================================================================

variable "resource_group_name" {
  description = "Name of the resource group where the VNet will be created"
  type        = string
}

variable "location" {
  description = "Azure region where resources will be created (e.g., 'eastus', 'westeurope')"
  type        = string
}

variable "vnet_name" {
  description = "Name of the Virtual Network. Should be descriptive (e.g., 'prod-vnet', 'hub-vnet')"
  type        = string
}

variable "address_space" {
  description = "List of address spaces (CIDR blocks) for the VNet. Example: ['10.0.0.0/16']"
  type        = list(string)

  validation {
    condition     = length(var.address_space) > 0
    error_message = "At least one address space must be specified."
  }
}

variable "subnets" {
  description = <<-EOT
    Map of subnet configurations. Each subnet can have:
    - address_prefixes: List of CIDR blocks for the subnet
    - service_endpoints: List of service endpoints to enable (e.g., ["Microsoft.Storage", "Microsoft.Sql"])
    - delegation: Service delegation configuration
    - private_endpoint_network_policies_enabled: Enable/disable private endpoint network policies
    - private_link_service_network_policies_enabled: Enable/disable private link service network policies
    
    Example:
    subnets = {
      "subnet1" = {
        address_prefixes = ["10.0.1.0/24"]
        service_endpoints = ["Microsoft.Storage"]
      }
    }
  EOT
  type = map(object({
    address_prefixes  = list(string)
    service_endpoints = optional(list(string), [])
    delegation = optional(object({
      name = string
      service_delegation = object({
        name    = string
        actions = list(string)
      })
    }), null)
    private_endpoint_network_policies_enabled     = optional(bool, true)
    private_link_service_network_policies_enabled = optional(bool, true)
  }))

  default = {}
}

variable "network_security_groups" {
  description = <<-EOT
    Map of Network Security Group (NSG) configurations.
    NSGs act as a firewall at the network level, controlling inbound and outbound traffic.
    
    Each NSG can have:
    - rules: List of security rules (allow/deny traffic)
    - associate_to_subnets: List of subnet names to associate this NSG to
    
    Example:
    network_security_groups = {
      "web-nsg" = {
        rules = [
          {
            name                       = "AllowHTTP"
            priority                   = 1000
            direction                  = "Inbound"
            access                     = "Allow"
            protocol                   = "Tcp"
            source_port_range          = "*"
            destination_port_range     = "80"
            source_address_prefix      = "*"
            destination_address_prefix = "*"
          }
        ]
        associate_to_subnets = ["web-subnet"]
      }
    }
  EOT
  type = map(object({
    rules = list(object({
      name                                       = string
      priority                                   = number
      direction                                  = string # "Inbound" or "Outbound"
      access                                     = string # "Allow" or "Deny"
      protocol                                   = string # "Tcp", "Udp", "Icmp", "*"
      source_port_range                          = optional(string, "*")
      source_port_ranges                         = optional(list(string), [])
      destination_port_range                     = optional(string, "*")
      destination_port_ranges                    = optional(list(string), [])
      source_address_prefix                      = optional(string, "*")
      source_address_prefixes                    = optional(list(string), [])
      source_application_security_group_ids      = optional(list(string), [])
      destination_address_prefix                 = optional(string, "*")
      destination_address_prefixes               = optional(list(string), [])
      destination_application_security_group_ids = optional(list(string), [])
    }))
    associate_to_subnets = list(string)
  }))

  default = {}
}

variable "route_tables" {
  description = <<-EOT
    Map of Route Table configurations.
    Route tables control where network traffic is directed.
    
    Each route table can have:
    - routes: List of custom routes
    - associate_to_subnets: List of subnet names to associate this route table to
    
    Example:
    route_tables = {
      "hub-routes" = {
        routes = [
          {
            name           = "RouteToFirewall"
            address_prefix = "0.0.0.0/0"
            next_hop_type  = "VirtualAppliance"
            next_hop_ip    = "10.0.0.4"
          }
        ]
        associate_to_subnets = ["dmz-subnet"]
      }
    }
  EOT
  type = map(object({
    routes = list(object({
      name                   = string
      address_prefix         = string
      next_hop_type          = string # "VirtualNetworkGateway", "VnetLocal", "Internet", "VirtualAppliance", "None"
      next_hop_in_ip_address = optional(string, null)
    }))
    associate_to_subnets = list(string)
  }))

  default = {}
}

variable "ddos_protection_plan_id" {
  description = "Optional ID of a DDoS Protection Plan to associate with the VNet. Leave null to disable DDoS protection."
  type        = string
  default     = null
}

variable "enable_ddos_protection" {
  description = "Enable DDoS protection on the VNet. Requires ddos_protection_plan_id to be set."
  type        = bool
  default     = false
}

variable "dns_servers" {
  description = "List of custom DNS servers for the VNet. If empty, Azure's default DNS is used."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Map of tags to apply to all resources created by this module"
  type        = map(string)
  default     = {}
}

variable "enable_vm_protection" {
  description = "Enable VM protection for all VMs in the VNet (prevents accidental deletion)"
  type        = bool
  default     = false
}

