# ============================================================================
# Azure Firewall Module - Variables
# ============================================================================
# Azure Firewall is a managed, cloud-based network security service that
# protects your Azure Virtual Network resources. It's a fully stateful
# firewall as a service with built-in high availability and unrestricted
# cloud scalability.
#
# Key Features:
# - Network rules (Layer 3/4 filtering)
# - Application rules (FQDN-based filtering)
# - NAT rules (DNAT - Destination NAT)
# - Threat Intelligence filtering
# - Built-in high availability
# - Auto-scaling
# ============================================================================

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "firewall_name" {
  description = "Name of the Azure Firewall"
  type        = string
}

variable "sku_name" {
  description = "SKU name. Options: 'AZFW_Hub' (Standard), 'AZFW_VNet' (Premium)"
  type        = string
  default     = "AZFW_Hub"

  validation {
    condition     = contains(["AZFW_Hub", "AZFW_VNet"], var.sku_name)
    error_message = "SKU name must be either 'AZFW_Hub' (Standard) or 'AZFW_VNet' (Premium)."
  }
}

variable "sku_tier" {
  description = "SKU tier. Options: 'Standard' or 'Premium'"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.sku_tier)
    error_message = "SKU tier must be either 'Standard' or 'Premium'."
  }
}

variable "firewall_subnet_id" {
  description = "Subnet ID for the Azure Firewall. Must be named 'AzureFirewallSubnet' and have /26 or larger CIDR."
  type        = string
}

variable "public_ip_address_id" {
  description = "Public IP address ID for the Azure Firewall. Required for outbound internet access."
  type        = string
}

variable "management_subnet_id" {
  description = "Optional management subnet ID. Required for Premium SKU. Must be named 'AzureFirewallManagementSubnet'."
  type        = string
  default     = null
}

variable "management_public_ip_address_id" {
  description = "Optional management public IP address ID. Required for Premium SKU."
  type        = string
  default     = null
}

variable "zones" {
  description = "Availability zones for the firewall. Standard supports 1 zone, Premium supports all zones."
  type        = list(string)
  default     = null
}

variable "threat_intel_mode" {
  description = "Threat Intelligence mode. Options: 'Alert', 'Deny', 'Off'"
  type        = string
  default     = "Alert"

  validation {
    condition     = contains(["Alert", "Deny", "Off"], var.threat_intel_mode)
    error_message = "Threat Intelligence mode must be 'Alert', 'Deny', or 'Off'."
  }
}

variable "dns_servers" {
  description = "List of DNS servers for the firewall. If empty, Azure DNS is used."
  type        = list(string)
  default     = []
}

variable "private_ip_ranges" {
  description = "List of private IP ranges. Traffic to these ranges bypasses the firewall."
  type        = list(string)
  default     = []
}

variable "network_rule_collections" {
  description = <<-EOT
    List of network rule collections.
    Network rules filter traffic based on source/destination IP, ports, and protocols.
    
    Example:
    network_rule_collections = [
      {
        name     = "AllowInternet"
        priority = 100
        action   = "Allow"
        rules = [
          {
            name                  = "AllowHTTPS"
            source_addresses      = ["*"]
            destination_addresses = ["*"]
            destination_ports     = ["443"]
            protocols             = ["TCP"]
          }
        ]
      }
    ]
  EOT
  type = list(object({
    name     = string
    priority = number
    action   = string # "Allow" or "Deny"
    rules = list(object({
      name                  = string
      source_addresses      = list(string)
      destination_addresses = list(string)
      destination_ports     = list(string)
      protocols             = list(string) # "TCP", "UDP", "ICMP", "Any"
    }))
  }))

  default = []
}

variable "application_rule_collections" {
  description = <<-EOT
    List of application rule collections.
    Application rules filter traffic based on FQDNs (Fully Qualified Domain Names).
    
    Example:
    application_rule_collections = [
      {
        name     = "AllowAzureServices"
        priority = 100
        action   = "Allow"
        rules = [
          {
            name             = "AllowStorage"
            source_addresses = ["10.0.0.0/16"]
            target_fqdns     = ["*.blob.core.windows.net"]
            protocol {
              type = "Https"
              port = 443
            }
          }
        ]
      }
    ]
  EOT
  type = list(object({
    name     = string
    priority = number
    action   = string # "Allow" or "Deny"
    rules = list(object({
      name             = string
      source_addresses = list(string)
      target_fqdns     = list(string)
      protocol = object({
        type = string # "Http", "Https", "Mssql"
        port = number
      })
    }))
  }))

  default = []
}

variable "nat_rule_collections" {
  description = <<-EOT
    List of NAT rule collections.
    NAT rules perform Destination NAT (DNAT) - translate public IP:port to private IP:port.
    
    Example:
    nat_rule_collections = [
      {
        name     = "WebServerDNAT"
        priority = 100
        rules = [
          {
            name                = "WebServer"
            source_addresses    = ["*"]
            destination_address = "20.1.2.3" # Firewall public IP
            destination_ports   = ["80"]
            translated_address  = "10.0.1.10" # Internal server
            translated_port     = "8080"
            protocols           = ["TCP", "UDP"]
          }
        ]
      }
    ]
  EOT
  type = list(object({
    name     = string
    priority = number
    rules = list(object({
      name                = string
      source_addresses    = list(string)
      destination_address = string
      destination_ports   = list(string)
      translated_address  = string
      translated_port     = string
      protocols           = list(string) # "TCP", "UDP"
    }))
  }))

  default = []
}

variable "tags" {
  description = "Map of tags"
  type        = map(string)
  default     = {}
}

