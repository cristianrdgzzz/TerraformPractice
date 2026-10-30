# ============================================================================
# Azure Virtual WAN Module - Main Configuration
# ============================================================================
# Virtual WAN provides:
# - Hub-spoke architecture
# - Branch connectivity (VPN, ExpressRoute)
# - VNet connectivity
# - Centralized security (Azure Firewall)
# - SD-WAN integration
#
# Architecture:
# Virtual WAN
#     ├── Virtual Hub 1 (Region 1)
#     │   ├── VPN Gateway
#     │   ├── ExpressRoute Gateway
#     │   ├── Azure Firewall
#     │   └── VNet Connections
#     └── Virtual Hub 2 (Region 2)
#         ├── VPN Gateway
#         └── VNet Connections
# ============================================================================

# ----------------------------------------------------------------------------
# Virtual WAN
# ----------------------------------------------------------------------------
# Virtual WAN is a networking service that brings together many networking,
# security, and routing functionalities into a single operational interface.
#
# Types:
# - Basic: Limited features, no Azure Firewall, no ExpressRoute
# - Standard: Full features, Azure Firewall, ExpressRoute, SD-WAN
#
# Key Features:
# - Hub-spoke architecture
# - Branch connectivity (VPN, ExpressRoute)
# - VNet connectivity
# - Centralized security
# - SD-WAN integration
# ----------------------------------------------------------------------------
resource "azurerm_virtual_wan" "main" {
  name                = var.virtual_wan_name
  location            = var.location
  resource_group_name = var.resource_group_name
  type                = var.type

  allow_branch_to_branch_traffic    = var.allow_branch_to_branch_traffic
  disable_vpn_encryption            = var.disable_vpn_encryption
  office365_local_breakout_category = var.office365_local_breakout_category

  tags = var.tags
}

# ----------------------------------------------------------------------------
# Virtual Hubs
# ----------------------------------------------------------------------------
# Virtual Hubs are the central connectivity points in Virtual WAN.
# They provide:
# - VPN Gateway (for site-to-site and point-to-site VPN)
# - ExpressRoute Gateway (for ExpressRoute connections)
# - Azure Firewall (for centralized security)
# - VNet connections (for connecting Virtual Networks)
#
# SKU Options:
# - Basic: Limited features
# - Standard: Full features
# ----------------------------------------------------------------------------
resource "azurerm_virtual_hub" "main" {
  for_each = var.virtual_hubs

  name                   = each.value.name
  location               = var.location
  resource_group_name    = var.resource_group_name
  virtual_wan_id         = azurerm_virtual_wan.main.id
  address_prefix         = each.value.address_prefix
  sku                    = each.value.sku
  hub_routing_preference = each.value.hub_routing_preference

  tags = merge(var.tags, each.value.tags)
}

# Note: VPN Gateway, ExpressRoute Gateway, Azure Firewall, and VNet connections
# are typically created separately and associated with the virtual hub.
# This module provides the foundation (Virtual WAN and Hubs).
# Additional resources can be added via separate modules or configurations.

