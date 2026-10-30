# ============================================================================
# Azure ExpressRoute Module - Variables
# ============================================================================
# ExpressRoute provides private connectivity between on-premises networks
# and Azure via dedicated circuits through connectivity providers.
# ============================================================================

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "express_route_circuit_name" {
  description = "Name of the ExpressRoute circuit"
  type        = string
}

variable "service_provider_name" {
  description = "Name of the ExpressRoute service provider (e.g., 'Equinix', 'Colt', 'AT&T')"
  type        = string
}

variable "peering_location" {
  description = "Name of the peering location (e.g., 'Washington DC', 'London')"
  type        = string
}

variable "bandwidth_in_mbps" {
  description = "Bandwidth in Mbps. Options: 50, 100, 200, 500, 1000, 2000, 5000, 10000"
  type        = number

  validation {
    condition     = contains([50, 100, 200, 500, 1000, 2000, 5000, 10000], var.bandwidth_in_mbps)
    error_message = "Bandwidth must be one of: 50, 100, 200, 500, 1000, 2000, 5000, 10000 Mbps."
  }
}

variable "sku" {
  description = <<-EOT
    SKU configuration for ExpressRoute circuit.
    
    Example:
    sku = {
      tier   = "Standard"  # "Standard" or "Premium"
      family = "MeteredData"  # "MeteredData" or "UnlimitedData"
    }
  EOT
  type = object({
    tier   = string # "Standard" or "Premium"
    family = string # "MeteredData" or "UnlimitedData"
  })
  default = {
    tier   = "Standard"
    family = "MeteredData"
  }
}

variable "allow_classic_operations" {
  description = "Allow classic operations (not recommended)"
  type        = bool
  default     = false
}

variable "express_route_gateway_name" {
  description = "Name of the ExpressRoute Gateway"
  type        = string
}

variable "gateway_ip_configuration" {
  description = <<-EOT
    Gateway IP configuration (subnet for ExpressRoute Gateway).
    The subnet must be named 'GatewaySubnet' and have minimum /27 CIDR.
  EOT
  type = object({
    name      = string
    subnet_id = string
  })
}

variable "gateway_public_ip_configuration" {
  description = <<-EOT
    Public IP configuration for ExpressRoute Gateway.
  EOT
  type = object({
    name              = string
    allocation_method = string # "Static" or "Dynamic"
    sku               = string # "Standard"
  })
}

variable "gateway_sku" {
  description = "ExpressRoute Gateway SKU. Options: 'Standard', 'HighPerformance', 'UltraPerformance', 'ErGw1AZ', 'ErGw2AZ', 'ErGw3AZ'"
  type        = string
  default     = "ErGw2AZ"
}

variable "express_route_connection_name" {
  description = "Name of the ExpressRoute connection"
  type        = string
}

variable "routing_weight" {
  description = "Routing weight for the connection (0-10000)"
  type        = number
  default     = 10
}

variable "authorization_key" {
  description = "Authorization key for the ExpressRoute circuit (optional)"
  type        = string
  default     = null
  sensitive   = true
}

variable "tags" {
  description = "Map of tags"
  type        = map(string)
  default     = {}
}

