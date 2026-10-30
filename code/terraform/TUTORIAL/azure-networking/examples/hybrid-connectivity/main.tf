# ============================================================================
# Hybrid Connectivity Example
# ============================================================================
# This example demonstrates hybrid connectivity between on-premises networks
# and Azure using VPN Gateway and ExpressRoute.
#
# Architecture:
# - Virtual Network with Gateway Subnet
# - VPN Gateway for site-to-site VPN
# - ExpressRoute Gateway (optional, commented)
# - Network Security Groups
# - Route Tables for traffic routing
# ============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# ----------------------------------------------------------------------------
# Provider Configuration
# ----------------------------------------------------------------------------
provider "azurerm" {
  features {}
}

# ----------------------------------------------------------------------------
# Resource Group
# ----------------------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = "rg-hybrid-connectivity"
  location = "eastus"

  tags = {
    Environment = "Example"
    ManagedBy   = "Terraform"
  }
}

# ----------------------------------------------------------------------------
# Virtual Network Module
# ----------------------------------------------------------------------------
# Creates the base network infrastructure with gateway subnet
# ----------------------------------------------------------------------------
module "vnet" {
  source = "../../modules/networking"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  vnet_name           = "vnet-hybrid"
  address_space       = ["10.0.0.0/16"]

  subnets = {
    "gateway-subnet" = {
      address_prefixes = ["10.0.1.0/27"] # Minimum /27 for VPN Gateway
    }
    "web-subnet" = {
      address_prefixes = ["10.0.2.0/24"]
    }
    "app-subnet" = {
      address_prefixes = ["10.0.3.0/24"]
    }
  }

  network_security_groups = {
    "web-nsg" = {
      rules = [
        {
          name                       = "AllowFromOnPremises"
          priority                   = 1000
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "*"
          source_address_prefix      = "192.168.0.0/16" # On-premises network
          destination_address_prefix = "*"
        }
      ]
      associate_to_subnets = ["web-subnet"]
    }
  }

  # Route Tables for hybrid connectivity
  route_tables = {
    "hybrid-routes" = {
      disable_bgp_route_propagation = false # Allow BGP routes
      routes = [
        {
          name                   = "RouteToOnPremises"
          address_prefix         = "192.168.0.0/16"
          next_hop_type          = "VirtualNetworkGateway"
          next_hop_in_ip_address = null
        }
      ]
      associate_to_subnets = ["web-subnet", "app-subnet"]
    }
  }

  tags = {
    Environment = "Example"
    ManagedBy   = "Terraform"
  }
}

# ----------------------------------------------------------------------------
# Public IP for VPN Gateway
# ----------------------------------------------------------------------------
resource "azurerm_public_ip" "vpn_gateway" {
  name                = "pip-vpn-gateway"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Environment = "Example"
    ManagedBy   = "Terraform"
  }
}

# ----------------------------------------------------------------------------
# VPN Gateway Module
# ----------------------------------------------------------------------------
# Creates a VPN Gateway for site-to-site connectivity
# Supports BGP for dynamic routing
# ----------------------------------------------------------------------------
module "vpn_gateway" {
  source = "../../modules/vpn-gateway"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  vpn_gateway_name    = "vpn-gateway-hybrid"

  vpn_type = "RouteBased" # Dynamic routing
  sku      = "VpnGw2"     # 1 Gbps throughput

  gateway_ip_configuration = {
    name      = "vnetGatewayConfig"
    subnet_id = module.vnet.subnet_ids["gateway-subnet"]
  }

  public_ip_configuration = {
    name              = "vpn-gateway-pip"
    allocation_method = "Static"
    sku               = "Standard"
  }

  active_active = false # Single active gateway

  # Enable BGP for dynamic routing
  enable_bgp = true
  bgp_settings = {
    asn         = 65515 # Azure default BGP ASN
    peer_weight = 0
  }

  tags = {
    Environment = "Example"
    ManagedBy   = "Terraform"
  }
}

# ----------------------------------------------------------------------------
# Local Network Gateway
# ----------------------------------------------------------------------------
# Represents your on-premises VPN device
# This is typically created separately and connected via a connection resource
# ----------------------------------------------------------------------------
resource "azurerm_local_network_gateway" "on_premises" {
  name                = "lng-on-premises"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  gateway_address     = "203.0.113.1"      # Replace with your on-premises VPN device IP
  address_space       = ["192.168.0.0/16"] # On-premises network address space

  # BGP Settings (if using BGP)
  bgp_settings {
    asn                 = 65001 # Your on-premises BGP ASN
    bgp_peering_address = "192.168.0.1"
  }

  tags = {
    Environment = "Example"
    ManagedBy   = "Terraform"
  }
}

# ----------------------------------------------------------------------------
# VPN Connection
# ----------------------------------------------------------------------------
# Connects the VPN Gateway to the Local Network Gateway
# ----------------------------------------------------------------------------
resource "azurerm_virtual_network_gateway_connection" "on_premises" {
  name                = "vpn-connection-on-premises"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  type                       = "IPsec"
  virtual_network_gateway_id = module.vpn_gateway.vpn_gateway_id
  local_network_gateway_id   = azurerm_local_network_gateway.on_premises.id

  # Shared key for IPsec connection
  # In production, use Azure Key Vault to store this securely
  shared_key = "YourSharedKey123!" # Replace with a secure shared key

  # Enable BGP if using dynamic routing
  enable_bgp = true

  tags = {
    Environment = "Example"
    ManagedBy   = "Terraform"
  }
}

# ----------------------------------------------------------------------------
# ExpressRoute Gateway (Optional)
# ----------------------------------------------------------------------------
# Uncomment this section if you want to use ExpressRoute instead of or
# in addition to VPN Gateway
# ----------------------------------------------------------------------------
# resource "azurerm_public_ip" "expressroute_gateway" {
#   name                = "pip-er-gateway"
#   location            = azurerm_resource_group.main.location
#   resource_group_name = azurerm_resource_group.main.name
#   allocation_method   = "Static"
#   sku                 = "Standard"
# }
#
# module "expressroute" {
#   source = "../../modules/expressroute"
#   
#   resource_group_name = azurerm_resource_group.main.name
#   location            = azurerm_resource_group.main.location
#   
#   express_route_circuit_name = "er-circuit-main"
#   service_provider_name      = "Colt"
#   peering_location           = "London"
#   bandwidth_in_mbps          = 1000
#   
#   sku = {
#     tier   = "Standard"
#     family = "MeteredData"
#   }
#   
#   express_route_gateway_name = "gw-expressroute"
#   gateway_sku                = "ErGw5AZ"
#   
#   gateway_ip_configuration = {
#     name      = "vnetGatewayConfig"
#     subnet_id = module.vnet.subnet_ids["gateway-subnet"]
#   }
#   
#   gateway_public_ip_configuration = {
#     name              = "er-gateway-pip"
#     allocation_method = "Static"
#     sku               = "Standard"
#   }
#   
#   express_route_connection_name = "er-connection-main"
#   routing_weight                = 10
# }

