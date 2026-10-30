# ============================================================================
# Azure ExpressRoute Module - Main Configuration
# ============================================================================
# ExpressRoute provides private connectivity between on-premises networks
# and Azure via dedicated circuits through connectivity providers.
#
# Architecture:
# On-Premises Network
#     ↓
# Connectivity Provider (e.g., Colt, Equinix)
#     ↓
# Microsoft Peering Location
#     ↓
# ExpressRoute Circuit
#     ↓
# ExpressRoute Gateway
#     ↓
# Azure Virtual Network
# ============================================================================

# ----------------------------------------------------------------------------
# ExpressRoute Circuit
# ----------------------------------------------------------------------------
# ExpressRoute Circuit represents the physical connection between your
# on-premises network and Microsoft's network through a connectivity provider.
#
# Key Features:
# - Private connectivity (not over Internet)
# - High bandwidth (up to 100 Gbps)
# - Predictable performance
# - Global reach
# - 99.95% uptime SLA
#
# SKU Tiers:
# - Standard: Basic features, regional connectivity
# - Premium: Additional features, global connectivity, more routes
#
# SKU Families:
# - MeteredData: Pay for data transfer
# - UnlimitedData: Unlimited data transfer
# ----------------------------------------------------------------------------
resource "azurerm_express_route_circuit" "main" {
  name                  = var.express_route_circuit_name
  location              = var.location
  resource_group_name   = var.resource_group_name
  service_provider_name = var.service_provider_name
  peering_location      = var.peering_location
  bandwidth_in_mbps     = var.bandwidth_in_mbps

  sku {
    tier   = var.sku.tier
    family = var.sku.family
  }

  allow_classic_operations = var.allow_classic_operations

  tags = var.tags
}

# ----------------------------------------------------------------------------
# Public IP for ExpressRoute Gateway
# ----------------------------------------------------------------------------
# ExpressRoute Gateway requires a public IP address.
# ----------------------------------------------------------------------------
resource "azurerm_public_ip" "gateway" {
  name                = var.gateway_public_ip_configuration.name
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = var.gateway_public_ip_configuration.allocation_method
  sku                 = var.gateway_public_ip_configuration.sku

  tags = var.tags
}

# ----------------------------------------------------------------------------
# ExpressRoute Gateway
# ----------------------------------------------------------------------------
# ExpressRoute Gateway connects the ExpressRoute circuit to the Virtual Network.
#
# SKU Options:
# - Standard: Up to 2 Gbps
# - HighPerformance: Up to 10 Gbps
# - UltraPerformance: Up to 10 Gbps (deprecated, use ErGw)
# - ErGw1AZ: 2 Gbps, zone-redundant
# - ErGw2AZ: 5 Gbps, zone-redundant
# - ErGw3AZ: 10 Gbps, zone-redundant
# ----------------------------------------------------------------------------
resource "azurerm_virtual_network_gateway" "expressroute" {
  name                = var.express_route_gateway_name
  location            = var.location
  resource_group_name = var.resource_group_name
  type                = "ExpressRoute"
  vpn_type            = null
  sku                 = var.gateway_sku

  ip_configuration {
    name                          = var.gateway_ip_configuration.name
    public_ip_address_id          = azurerm_public_ip.gateway.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = var.gateway_ip_configuration.subnet_id
  }

  tags = var.tags
}

# ----------------------------------------------------------------------------
# ExpressRoute Connection
# ----------------------------------------------------------------------------
# ExpressRoute Connection links the ExpressRoute circuit to the gateway.
# ----------------------------------------------------------------------------
resource "azurerm_express_route_connection" "main" {
  name                     = var.express_route_connection_name
  express_route_gateway_id = azurerm_virtual_network_gateway.expressroute.id
  express_route_circuit_id = azurerm_express_route_circuit.main.id

  routing_weight = var.routing_weight

  # Authorization key (if provided)
  authorization_key = var.authorization_key
}

