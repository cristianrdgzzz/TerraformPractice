# ============================================================================
# Azure Route Server Module - Main Configuration
# ============================================================================
# Azure Route Server enables dynamic routing between your network virtual
# appliances (NVAs) and Azure Virtual Networks using BGP (Border Gateway Protocol).
#
# Key Features:
# - Dynamic route exchange with NVAs via BGP
# - Automatic route propagation to all VMs in the VNet
# - Integration with Azure VPN Gateway and ExpressRoute Gateway
# - Support for multiple BGP peers (NVAs)
# - High availability with Standard SKU
#
# Architecture:
# NVA (BGP Peer)
#     ↓
# Route Server (BGP Session)
#     ↓
# Route Propagation to VNet
#     ↓
# VMs and Resources
# ============================================================================

# ----------------------------------------------------------------------------
# Optional Resource Group Module
# ----------------------------------------------------------------------------
# This module can optionally create a resource group if create_resource_group
# is set to true. If false, it uses the provided resource_group_name variable.
# ----------------------------------------------------------------------------
module "resource_group" {
  source = "../resource-group"
  count  = var.create_resource_group ? 1 : 0

  project_name     = var.project_name
  application_name = var.application_name
  environment      = var.environment
  location         = var.location
  tags             = var.tags
}

# ----------------------------------------------------------------------------
# Local Values
# ----------------------------------------------------------------------------
locals {
  # Use the resource group name from the module if created, otherwise use the variable
  resource_group_name     = try(module.resource_group[0].name, var.resource_group_name)
  resource_group_location = try(module.resource_group[0].location, var.location)
}

# ----------------------------------------------------------------------------
# Public IP Address for Route Server
# ----------------------------------------------------------------------------
# Route Server requires a public IP address for BGP peering.
# The public IP is used for the Route Server's management interface.
# ----------------------------------------------------------------------------
resource "azurerm_public_ip" "route_server" {
  name                = "${var.route_server_name}-pip"
  location            = local.resource_group_location
  resource_group_name = local.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.zones

  tags = merge(var.tags, {
    Purpose = "Route Server Public IP"
  })
}

# ----------------------------------------------------------------------------
# Azure Route Server
# ----------------------------------------------------------------------------
# Route Server enables dynamic routing between NVAs and Azure Virtual Networks.
#
# Key Requirements:
# - Must be deployed in a dedicated subnet named "RouteServerSubnet"
# - Subnet must be /27 or larger (minimum /27, recommended /26 or /25)
# - Requires a public IP address
# - Standard SKU provides high availability
#
# BGP Configuration:
# - Route Server uses ASN 65515 (fixed, cannot be changed)
# - NVAs peer with Route Server using their own ASN
# - Routes learned from NVAs are automatically propagated to all VMs in the VNet
# - Routes from Azure (VNet routes) are advertised to NVAs
# ----------------------------------------------------------------------------
resource "azurerm_route_server" "main" {
  name                 = var.route_server_name
  location             = local.resource_group_location
  resource_group_name  = local.resource_group_name
  sku                  = var.sku
  subnet_id            = var.subnet_id
  public_ip_address_id = azurerm_public_ip.route_server.id

  branch_to_branch_traffic_enabled = var.branch_to_branch_traffic_enabled

  tags = var.tags
}

# ----------------------------------------------------------------------------
# BGP Peer Connections (NVAs)
# ----------------------------------------------------------------------------
# BGP peer connections allow NVAs to exchange routes with Route Server.
#
# Each NVA that needs to exchange routes with Route Server requires a BGP peer
# connection. The NVA must:
# - Be in the same VNet or a peered VNet
# - Have BGP enabled and configured
# - Use a unique ASN (different from Route Server's ASN 65515)
# - Have IP forwarding enabled on its network interface
#
# Route Exchange:
# - NVAs advertise their routes to Route Server
# - Route Server propagates NVA routes to all VMs in the VNet
# - Route Server advertises VNet routes to NVAs
# - This enables dynamic routing without manual route table configuration
# ----------------------------------------------------------------------------
resource "azurerm_route_server_bgp_connection" "peers" {
  for_each = var.bgp_peers

  name            = each.value.name
  route_server_id = azurerm_route_server.main.id
  peer_asn        = each.value.peer_asn
  peer_ip         = each.value.peer_ip
}

