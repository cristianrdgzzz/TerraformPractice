# ============================================================================
# Azure VPN Gateway Module - Variables
# ============================================================================
# VPN Gateway provides secure connectivity between on-premises networks
# and Azure Virtual Networks via site-to-site or point-to-site VPN.
# ============================================================================

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "vpn_gateway_name" {
  description = "Name of the VPN Gateway"
  type        = string
}

variable "vpn_type" {
  description = "VPN type. Options: 'RouteBased' (dynamic routing) or 'PolicyBased' (static routing)"
  type        = string
  default     = "RouteBased"

  validation {
    condition     = contains(["RouteBased", "PolicyBased"], var.vpn_type)
    error_message = "VPN type must be either 'RouteBased' or 'PolicyBased'."
  }
}

variable "sku" {
  description = "VPN Gateway SKU. Options: 'Basic', 'VpnGw1', 'VpnGw2', 'VpnGw3', 'VpnGw4', 'VpnGw5'"
  type        = string
  default     = "VpnGw2"

  validation {
    condition     = contains(["Basic", "VpnGw1", "VpnGw2", "VpnGw3", "VpnGw4", "VpnGw5"], var.sku)
    error_message = "SKU must be one of: Basic, VpnGw1, VpnGw2, VpnGw3, VpnGw4, VpnGw5."
  }
}

variable "gateway_ip_configuration" {
  description = <<-EOT
    Gateway IP configuration (subnet for VPN Gateway).
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
    Public IP configuration for VPN Gateway.
    
    Example:
    public_ip_configuration = {
      name              = "vpn-gateway-pip"
      allocation_method = "Static"
      sku               = "Standard"
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
  description = "Enable active-active mode (requires two public IPs)"
  type        = bool
  default     = false
}

variable "enable_bgp" {
  description = "Enable BGP (Border Gateway Protocol) for dynamic routing"
  type        = bool
  default     = false
}

variable "bgp_settings" {
  description = <<-EOT
    BGP settings (required if enable_bgp is true).
    
    Example:
    bgp_settings = {
      asn = 65515  # Azure default BGP ASN
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
    Point-to-Site VPN client configuration.
    
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
  description = "Map of tags"
  type        = map(string)
  default     = {}
}

