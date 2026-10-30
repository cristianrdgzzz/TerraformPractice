# ============================================================================
# Azure Virtual Network Module - Variables
# ============================================================================
# This module creates an Azure Virtual Network (VNet) with subnets.
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
  description = <<-EOT
    List of address spaces (CIDR blocks) for the VNet.
    Example: ['10.0.0.0/16'] or ['10.0.0.0/16', '172.16.0.0/16']
    
    Important:
    - Address space cannot be changed after creation
    - Must not overlap with on-premises networks if connecting via VPN/ExpressRoute
    - Plan carefully for future growth and connectivity requirements
  EOT
  type        = list(string)

  validation {
    condition     = length(var.address_space) > 0
    error_message = "At least one address space must be specified."
  }
}

variable "subnets" {
  description = <<-EOT
    Map of subnet configurations. Each subnet can have:
    - address_prefixes: List of CIDR blocks for the subnet (must be within VNet address space)
    - service_endpoints: List of service endpoints to enable (e.g., ["Microsoft.Storage", "Microsoft.Sql"])
    - delegation: Service delegation configuration (for AKS, App Service, etc.)
    - private_endpoint_network_policies_enabled: Enable/disable private endpoint network policies
    - private_link_service_network_policies_enabled: Enable/disable private link service network policies
    - route_table_name: Name of route table to associate with this subnet (must exist in route_tables)
    
    Example:
    subnets = {
      "subnet-web" = {
        address_prefixes = ["10.0.1.0/24"]
        service_endpoints = ["Microsoft.Storage"]
        route_table_name = "rt-nva"  # Associate route table
        private_endpoint_network_policies_enabled = true
        private_link_service_network_policies_enabled = true
      }
      "subnet-app" = {
        address_prefixes = ["10.0.2.0/24"]
        service_endpoints = ["Microsoft.Sql"]
        route_table_name = null  # No route table (uses system routes)
      }
      "GatewaySubnet" = {
        address_prefixes = ["10.0.0.0/27"]  # Minimum /27 for VPN/ExpressRoute Gateway
      }
    }
    
    Note: Azure reserves 5 IP addresses per subnet:
    - Network address (first)
    - Default gateway (second)
    - Two Azure DNS addresses (third and fourth)
    - Broadcast address (last)
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
    route_table_name                              = optional(string, null)
  }))

  default = {}
}

variable "dns_servers" {
  description = <<-EOT
    List of custom DNS servers for the VNet.
    If empty, Azure's default DNS (168.63.129.16) is used.
    
    Use cases:
    - Hybrid scenarios: Resolve on-premises resources
    - Custom DNS infrastructure: Use your own DNS servers
    - Active Directory: Use domain controllers as DNS servers
    
    Example: ["10.0.0.4", "10.0.0.5", "8.8.8.8"]
  EOT
  type        = list(string)
  default     = []
}

variable "ddos_protection_plan_id" {
  description = <<-EOT
    Optional ID of a DDoS Protection Plan to associate with the VNet.
    Leave null to disable DDoS protection.
    
    DDoS Protection Plan must be created separately (Standard tier).
    This is a paid service that provides advanced DDoS mitigation.
  EOT
  type        = string
  default     = null
}

variable "enable_ddos_protection" {
  description = <<-EOT
    Enable DDoS protection on the VNet.
    Requires ddos_protection_plan_id to be set.
    
    Note: DDoS Protection Standard is a paid service.
    Basic DDoS protection is always enabled (free).
  EOT
  type        = bool
  default     = false
}

variable "tags" {
  description = "Map of tags to apply to all resources created by this module"
  type        = map(string)
  default     = {}
}

variable "route_tables" {
  description = <<-EOT
    Map of route tables to create. Route tables allow you to override Azure's default routing behavior.
    
    Each route table can have:
    - disable_bgp_route_propagation: Disable propagation of BGP routes from on-premises (default: false)
    - tags: Additional tags for the route table
    
    Example:
    route_tables = {
      "rt-nva" = {
        disable_bgp_route_propagation = false
        tags = {
          Purpose = "NVA Routing"
        }
      }
      "rt-internet" = {
        disable_bgp_route_propagation = false
        tags = {}
      }
    }
  EOT
  type = map(object({
    disable_bgp_route_propagation = optional(bool, false)
    tags                          = optional(map(string), {})
  }))
  default = {}
}

variable "routes" {
  description = <<-EOT
    Map of user-defined routes to create. Routes define how traffic is routed to specific destinations.
    
    Each route requires:
    - name: Name of the route
    - route_table_name: Name of the route table (must exist in route_tables)
    - address_prefix: Destination network in CIDR notation (e.g., "10.1.0.0/16", "0.0.0.0/0")
    - next_hop_type: Type of next hop (see Next Hop Types below)
    - next_hop_in_ip_address: IP address for VirtualAppliance next hop type (optional)
    
    Next Hop Types:
    - VirtualAppliance: Route through Network Virtual Appliance (NVA)
      - Requires next_hop_in_ip_address (NVA's IP address)
      - Used for forced tunneling, traffic inspection, etc.
    - VirtualNetworkGateway: Route through VPN/ExpressRoute Gateway
      - Used for on-premises connectivity
      - Routes traffic to on-premises networks
    - VnetLocal: Route within the VNet (default for VNet subnets)
      - Used to route traffic within the VNet
    - Internet: Route to the Internet
      - Used for direct internet access
    - None: Drop traffic (blackhole route)
      - Used to block traffic to specific destinations
    - VnetPeering: Route to a peered VNet
      - Used for cross-VNet routing
    
    Route Evaluation:
    - Routes are evaluated in order of specificity (most specific first)
    - User-defined routes override system routes for matching prefixes
    - If multiple routes match, the most specific route is used
    
    Example:
    routes = {
      "route-nva-default" = {
        name                   = "route-nva-default"
        route_table_name       = "rt-nva"
        address_prefix         = "0.0.0.0/0"
        next_hop_type          = "VirtualAppliance"
        next_hop_in_ip_address = "10.0.1.10"  # NVA IP
      }
      "route-onprem" = {
        name             = "route-onprem"
        route_table_name = "rt-nva"
        address_prefix   = "10.1.0.0/16"
        next_hop_type    = "VirtualNetworkGateway"
      }
      "route-block" = {
        name             = "route-block"
        route_table_name = "rt-nva"
        address_prefix   = "192.168.0.0/16"
        next_hop_type    = "None"  # Blackhole route
      }
    }
  EOT
  type = map(object({
    name                   = string
    route_table_name       = string
    address_prefix         = string
    next_hop_type          = string
    next_hop_in_ip_address = optional(string, null)
  }))
  default = {}

  validation {
    condition = alltrue([
      for route in var.routes : contains([
        "VirtualAppliance",
        "VirtualNetworkGateway",
        "VnetLocal",
        "Internet",
        "None",
        "VnetPeering"
      ], route.next_hop_type)
    ])
    error_message = "next_hop_type must be one of: VirtualAppliance, VirtualNetworkGateway, VnetLocal, Internet, None, VnetPeering"
  }

  validation {
    condition = alltrue([
      for route in var.routes : route.next_hop_type != "VirtualAppliance" || route.next_hop_in_ip_address != null
    ])
    error_message = "next_hop_in_ip_address is required when next_hop_type is VirtualAppliance"
  }
}


