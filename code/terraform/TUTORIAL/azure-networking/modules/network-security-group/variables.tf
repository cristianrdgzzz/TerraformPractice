# ============================================================================
# Azure Network Security Group Module - Variables
# ============================================================================
# This module creates an Azure Network Security Group (NSG) with security rules.
#
# NSGs act as a firewall at the network level, controlling inbound and
# outbound traffic to Azure resources.
# ============================================================================

variable "resource_group_name" {
  description = "Name of the resource group where the NSG will be created"
  type        = string
}

variable "location" {
  description = "Azure region where the NSG will be created (e.g., 'eastus', 'westeurope')"
  type        = string
}

variable "nsg_name" {
  description = "Name of the Network Security Group"
  type        = string
}

variable "security_rules" {
  description = <<-EOT
    List of security rules for the NSG.
    
    Each rule defines:
    - name: Unique name for the rule
    - priority: Priority (100-4096, lower = higher priority)
    - direction: "Inbound" or "Outbound"
    - access: "Allow" or "Deny"
    - protocol: "Tcp", "Udp", "Icmp", or "*" (all)
    - source_port_range: Source port (e.g., "80", "*", "1000-2000")
    - destination_port_range: Destination port (e.g., "80", "*", "1000-2000")
    - source_address_prefix: Source IP/CIDR or service tag (e.g., "10.0.0.0/24", "VirtualNetwork", "Internet")
    - destination_address_prefix: Destination IP/CIDR or service tag
    
    Example:
    security_rules = [
      {
        name                       = "AllowHTTP"
        priority                   = 1000
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range    = "80"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
        description                = "Allow HTTP traffic"
      },
      {
        name                       = "AllowHTTPS"
        priority                   = 1100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range    = "443"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
        description                = "Allow HTTPS traffic"
      },
      {
        name                       = "AllowSSH"
        priority                   = 1200
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range    = "22"
        source_address_prefix      = "10.0.0.0/24"  # Only from specific subnet
        destination_address_prefix = "*"
        description                = "Allow SSH from internal subnet"
      }
    ]
    
    Service Tags (common):
    - VirtualNetwork: All IP addresses in the VNet
    - Internet: All public IP addresses
    - AzureLoadBalancer: Azure Load Balancer
    - Storage: Azure Storage service
    - Sql: Azure SQL Database
    - AzureKeyVault: Azure Key Vault
    
    Note: You can use either source_port_range or source_port_ranges (not both).
    Same applies to destination_port_range/destination_port_ranges and
    source_address_prefix/source_address_prefixes.
  EOT
  type = list(object({
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
    description                                = optional(string, null)
  }))

  default = []
}

variable "associate_to_subnets" {
  description = <<-EOT
    List of subnet IDs to associate this NSG to.
    
    When associated to a subnet:
    - All VMs in the subnet inherit the NSG rules
    - Rules are evaluated at the network interface level
    - You can also associate NSGs directly to network interfaces (more granular)
    
    Example:
    associate_to_subnets = [
      azurerm_subnet.web.id,
      azurerm_subnet.app.id
    ]
    
    Note: Leave empty if you want to associate NSG to network interfaces only.
  EOT
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Map of tags to apply to the NSG"
  type        = map(string)
  default     = {}
}


