# ============================================================================
# Azure Virtual Network Module - Main Configuration
# ============================================================================
# This module creates an Azure Virtual Network (VNet) with:
# - Virtual Network with configurable address spaces
# - Subnets with service endpoints and delegations
# - Optional DDoS Protection integration
# - Custom DNS server configuration
#
# Architecture:
# VNet (10.0.0.0/16)
#   ├── Subnet 1 (10.0.1.0/24) → Service Endpoints
#   ├── Subnet 2 (10.0.2.0/24) → Service Delegation
#   └── Subnet 3 (10.0.3.0/24) → Standard Subnet
# ============================================================================

# ----------------------------------------------------------------------------
# Virtual Network
# ----------------------------------------------------------------------------
# The VNet is the core networking component that provides:
# - Network isolation and segmentation
# - IP address space management
# - Subnet organization
# - DNS resolution
# - Optional DDoS protection
#
# Key Characteristics:
# - Logical isolation of Azure cloud resources
# - Each VNet has its own CIDR block
# - Can be linked to other VNets and on-premises networks
# - Address space cannot be changed after creation
# ----------------------------------------------------------------------------
resource "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.address_space

  # DDoS Protection: Protects against distributed denial-of-service attacks
  # Requires a DDoS Protection Plan (Standard tier) to be created separately
  # This is a paid service that provides advanced DDoS mitigation
  dynamic "ddos_protection_plan" {
    for_each = var.enable_ddos_protection && var.ddos_protection_plan_id != null ? [1] : []
    content {
      id     = var.ddos_protection_plan_id
      enable = true
    }
  }

  # Custom DNS servers: Useful for hybrid scenarios where you need to resolve
  # on-premises resources or use custom DNS infrastructure
  # If empty, Azure's default DNS (168.63.129.16) is used
  # Note: Azure reserves 4 IP addresses per subnet (network, gateway, 2x DNS)
  dns_servers = var.dns_servers

  tags = var.tags
}

# ----------------------------------------------------------------------------
# Subnets
# ----------------------------------------------------------------------------
# Subnets segment the VNet into smaller networks. Each subnet:
# - Must be within the VNet's address space
# - Cannot overlap with other subnets
# - Has 5 reserved IP addresses (network, gateway, 2x DNS, broadcast)
# - Can have service endpoints for Azure services (Storage, SQL, etc.)
# - Can be delegated to specific Azure services (e.g., AKS, App Service)
# - Can have network policies for private endpoints/private links
#
# Reserved Addresses per Subnet:
# - First address: Network address (e.g., 10.0.1.0)
# - Second address: Default gateway (e.g., 10.0.1.1)
# - Third and fourth: Azure DNS (e.g., 10.0.1.2, 10.0.1.3)
# - Last address: Broadcast address (e.g., 10.0.1.255)
# ----------------------------------------------------------------------------
resource "azurerm_subnet" "main" {
  for_each = var.subnets

  name                 = each.key
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = each.value.address_prefixes

  # Service Endpoints: Extend VNet identity to Azure services
  # This allows services like Storage Accounts and SQL Databases to be
  # accessed from the VNet without going through the public internet
  # Traffic stays on Azure's backbone network
  # Available services: Microsoft.Storage, Microsoft.Sql, Microsoft.KeyVault, etc.
  service_endpoints = each.value.service_endpoints

  # Service Delegation: Delegates subnet management to Azure services
  # Example: Delegating to "Microsoft.ContainerService/managedClusters"
  # allows AKS to manage the subnet (creates required resources automatically)
  dynamic "delegation" {
    for_each = each.value.delegation != null ? [each.value.delegation] : []
    content {
      name = delegation.value.name
      service_delegation {
        name    = delegation.value.service_delegation.name
        actions = delegation.value.service_delegation.actions
      }
    }
  }

  # Private Endpoint Network Policies:
  # When enabled, allows private endpoints to be created in this subnet
  # Private endpoints provide private IP connectivity to Azure services
  private_endpoint_network_policies_enabled = each.value.private_endpoint_network_policies_enabled

  # Private Link Service Network Policies:
  # When enabled, allows private link services to be created in this subnet
  # Private link services expose your services privately to other VNets
  private_link_service_network_policies_enabled = each.value.private_link_service_network_policies_enabled
}

# ----------------------------------------------------------------------------
# Route Tables (User-Defined Routes)
# ----------------------------------------------------------------------------
# Route Tables allow you to override Azure's default routing behavior.
# You can create custom routes to control how traffic flows in your VNet.
#
# Route tables can be associated with subnets to apply custom routing rules.
# Each subnet can have only one route table associated with it.
#
# Route Priority:
# - Routes are evaluated in order of specificity (most specific first)
# - System routes (default Azure routes) have lower priority than user-defined routes
# - If multiple routes match, the most specific route is used
# ----------------------------------------------------------------------------
resource "azurerm_route_table" "main" {
  for_each = var.route_tables

  name                          = each.key
  location                      = var.location
  resource_group_name           = var.resource_group_name
  disable_bgp_route_propagation = each.value.disable_bgp_route_propagation

  tags = merge(var.tags, each.value.tags)
}

# ----------------------------------------------------------------------------
# Routes (User-Defined Routes)
# ----------------------------------------------------------------------------
# Routes define how traffic is routed to specific destinations.
# Each route specifies:
# - Address prefix: Destination network (CIDR notation)
# - Next hop type: Where to send the traffic
# - Next hop IP: IP address (for VirtualAppliance next hop type)
#
# Next Hop Types:
# - VirtualAppliance: Route traffic through a Network Virtual Appliance (NVA)
# - VirtualNetworkGateway: Route traffic through VPN/ExpressRoute Gateway
# - VnetLocal: Route traffic within the VNet (default for VNet subnets)
# - Internet: Route traffic to the Internet
# - None: Drop traffic (blackhole route)
# - VnetPeering: Route traffic to a peered VNet
#
# Route Evaluation:
# - Routes are evaluated in order of specificity
# - Most specific route (smallest prefix) is matched first
# - If no user-defined route matches, system routes are used
# ----------------------------------------------------------------------------
resource "azurerm_route" "main" {
  for_each = {
    for route_key, route in var.routes : route_key => route
    if route.route_table_name != null
  }

  name                   = each.value.name
  resource_group_name    = var.resource_group_name
  route_table_name       = azurerm_route_table.main[each.value.route_table_name].name
  address_prefix         = each.value.address_prefix
  next_hop_type          = each.value.next_hop_type
  next_hop_in_ip_address = each.value.next_hop_in_ip_address

  # Note: next_hop_in_ip_address is required only for VirtualAppliance next hop type
}

# ----------------------------------------------------------------------------
# Subnet Route Table Associations
# ----------------------------------------------------------------------------
# Associates route tables with subnets to apply custom routing rules.
# Each subnet can have only one route table associated with it.
#
# When a route table is associated with a subnet:
# - All traffic from resources in that subnet uses the route table
# - User-defined routes override system routes for matching prefixes
# - Routes are evaluated in order of specificity
# ----------------------------------------------------------------------------
resource "azurerm_subnet_route_table_association" "main" {
  for_each = {
    for subnet_name, subnet_config in var.subnets : subnet_name => subnet_config
    if subnet_config.route_table_name != null
  }

  subnet_id      = azurerm_subnet.main[each.key].id
  route_table_id = azurerm_route_table.main[each.value.route_table_name].id
}


