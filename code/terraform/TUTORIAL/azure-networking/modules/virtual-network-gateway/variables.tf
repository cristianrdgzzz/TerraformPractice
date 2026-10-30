# ============================================================================
# Azure Virtual Network Gateway Module - Variables
# ============================================================================
# Virtual Network Gateway provides secure connectivity between on-premises
# networks and Azure Virtual Networks via VPN or ExpressRoute.
# ============================================================================

variable "resource_group_name" {
  description = "Name of the resource group where the gateway will be created"
  type        = string
}

variable "location" {
  description = "Azure region where the gateway will be created (e.g., 'eastus', 'westeurope')"
  type        = string
}

variable "gateway_name" {
  description = "Name of the Virtual Network Gateway"
  type        = string
}

variable "gateway_type" {
  description = <<-EOT
    Type of Virtual Network Gateway.
    Options: 'Vpn' (VPN Gateway) or 'ExpressRoute' (ExpressRoute Gateway)
    
    - Vpn: Site-to-Site, Point-to-Site, VNet-to-VNet VPN
    - ExpressRoute: Private, dedicated connectivity via service provider
  EOT
  type        = string

  validation {
    condition     = contains(["Vpn", "ExpressRoute"], var.gateway_type)
    error_message = "Gateway type must be either 'Vpn' or 'ExpressRoute'."
  }
}

variable "vpn_type" {
  description = <<-EOT
    VPN type (only applicable when gateway_type is 'Vpn').
    Options: 'RouteBased' (dynamic routing) or 'PolicyBased' (static routing)
    
    - RouteBased: Dynamic routing (BGP), recommended for most scenarios
    - PolicyBased: Static routing, limited features, legacy
  EOT
  type        = string
  default     = "RouteBased"

  validation {
    condition     = contains(["RouteBased", "PolicyBased"], var.vpn_type)
    error_message = "VPN type must be either 'RouteBased' or 'PolicyBased'."
  }
}

variable "sku" {
  description = <<-EOT
    Gateway SKU.
    
    For VPN Gateway:
    - Basic: 100 Mbps, 10 tunnels, no BGP (development/testing only)
    - VpnGw1: 650 Mbps, 30 tunnels, BGP support
    - VpnGw2: 1 Gbps, 30 tunnels, BGP support (recommended)
    - VpnGw3: 1.25 Gbps, 30 tunnels, BGP support
    - VpnGw4: 5 Gbps, 100 tunnels, BGP support
    - VpnGw5: 10 Gbps, 100 tunnels, BGP support
    
    For ExpressRoute Gateway:
    - Standard: Up to 10 Gbps
    - HighPerformance: Up to 20 Gbps
    - UltraPerformance: Up to 100 Gbps
  EOT
  type        = string
  default     = "VpnGw2"
}

variable "gateway_ip_configuration" {
  description = <<-EOT
    Gateway IP configuration (subnet for Virtual Network Gateway).
    The subnet must be named 'GatewaySubnet' and have minimum /27 CIDR.
    
    Example:
    gateway_ip_configuration = {
      name      = "vnetGatewayConfig"
      subnet_id = azurerm_subnet.gateway.id
    }
  EOT
  type = object({
    name      = string
    subnet_id = string
  })
}

variable "public_ip_configuration" {
  description = <<-EOT
    Public IP configuration for Virtual Network Gateway.
    
    Example:
    public_ip_configuration = {
      name              = "gateway-pip"
      allocation_method = "Static"
      sku               = "Standard"
      zones             = ["1", "2", "3"]  # Optional, for zone redundancy
    }
  EOT
  type = object({
    name              = string
    allocation_method = string # "Static" or "Dynamic"
    sku               = string # "Basic" or "Standard"
    zones             = optional(list(string), [])
  })
}

variable "active_active" {
  description = <<-EOT
    Enable active-active mode (requires two public IPs).
    
    Active-active mode provides:
    - Higher availability: Two active gateways
    - Load balancing: Traffic distributed across both gateways
    - Faster failover: Automatic failover if one gateway fails
    
    Note: Requires two public IP addresses.
  EOT
  type        = bool
  default     = false
}

variable "enable_bgp" {
  description = <<-EOT
    Enable BGP (Border Gateway Protocol) for dynamic routing.
    
    BGP provides:
    - Dynamic routing: Automatic route updates
    - Path selection: Best path selection
    - Failover: Automatic failover between paths
    
    Required for:
    - ExpressRoute Gateway
    - Advanced VPN scenarios
  EOT
  type        = bool
  default     = false
}

variable "bgp_settings" {
  description = <<-EOT
    BGP settings (required if enable_bgp is true).
    
    Example:
    bgp_settings = {
      asn = 65515  # Azure default BGP ASN (or your ASN)
      peer_weight = 0
      peering_addresses = []  # Auto-assigned if empty
    }
  EOT
  type = object({
    asn               = number
    peer_weight       = optional(number, 0)
    peering_addresses = optional(list(string), [])
  })
  default = null
}

variable "vpn_client_configuration" {
  description = <<-EOT
    Point-to-Site VPN client configuration (only applicable for VPN Gateway).
    
    Example:
    vpn_client_configuration = {
      address_space = ["172.16.0.0/24"]
      root_certificates = [
        {
          name             = "root-cert"
          public_cert_data = file("root-cert.pem")
        }
      ]
      revoked_certificates = []
      radius_server_address = null
      radius_server_secret   = null
      vpn_client_protocols   = ["OpenVPN", "IkeV2"]
    }
  EOT
  type = object({
    address_space = list(string)
    root_certificates = optional(list(object({
      name             = string
      public_cert_data = string
    })), [])
    revoked_certificates = optional(list(object({
      name       = string
      thumbprint = string
    })), [])
    radius_server_address = optional(string, null)
    radius_server_secret  = optional(string, null)
    vpn_client_protocols  = optional(list(string), ["OpenVPN", "IkeV2"])
  })
  default = null
}

variable "tags" {
  description = "Map of tags to apply to all resources created by this module"
  type        = map(string)
  default     = {}
}


