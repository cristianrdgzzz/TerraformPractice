# ============================================================================
# Virtual Network Module - Main Configuration
# ============================================================================
# This module creates a complete Azure Virtual Network infrastructure including:
# - Virtual Network (VNet) with configurable address spaces
# - Subnets with service endpoints and delegations
# - Network Security Groups (NSGs) with custom rules
# - Route Tables with custom routes
# - Optional DDoS Protection integration
#
# Architecture:
# VNet (10.0.0.0/16)
#   ├── Subnet 1 (10.0.1.0/24) → NSG 1 → Route Table 1
#   ├── Subnet 2 (10.0.2.0/24) → NSG 2 → Route Table 2
#   └── Subnet 3 (10.0.3.0/24) → NSG 1 → Route Table 1
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
# ----------------------------------------------------------------------------
resource "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.address_space

  # DDoS Protection: Protects against distributed denial-of-service attacks
  # Requires a DDoS Protection Plan (Standard tier) to be created separately
  # This is a paid service that provides advanced DDoS mitigation
  ddos_protection_plan {
    id     = var.ddos_protection_plan_id
    enable = var.enable_ddos_protection
  }

  # Custom DNS servers: Useful for hybrid scenarios where you need to resolve
  # on-premises resources or use custom DNS infrastructure
  # If empty, Azure's default DNS (168.63.129.16) is used
  dns_servers = var.dns_servers

  # Note: VM Protection is not directly configurable on the VNet resource
  # VM protection is configured at the VM level using the 'protection_policy' block

  tags = var.tags
}

# ----------------------------------------------------------------------------
# Subnets
# ----------------------------------------------------------------------------
# Subnets segment the VNet into smaller networks. Each subnet:
# - Must be within the VNet's address space
# - Cannot overlap with other subnets
# - Can have service endpoints for Azure services (Storage, SQL, etc.)
# - Can be delegated to specific Azure services (e.g., AKS, App Service)
# - Can have network policies for private endpoints/private links
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
  # Note: This attribute may vary by Azure provider version
  # private_endpoint_network_policies_enabled = each.value.private_endpoint_network_policies_enabled

  # Private Link Service Network Policies:
  # When enabled, allows private link services to be created in this subnet
  # Private link services expose your services privately to other VNets
  # Note: This attribute may vary by Azure provider version
  # private_link_service_network_policies_enabled = each.value.private_link_service_network_policies_enabled
}

# ----------------------------------------------------------------------------
# Network Security Groups (NSGs)
# ----------------------------------------------------------------------------
# NSGs act as a distributed firewall at the network level:
# - Rules are evaluated at the VM's network interface level
# - Rules can be inbound or outbound
# - Rules have priorities (lower number = higher priority)
# - Default rules allow all outbound and deny all inbound (except VNet traffic)
# - NSGs can be associated to subnets or network interfaces
# ----------------------------------------------------------------------------
resource "azurerm_network_security_group" "main" {
  for_each = var.network_security_groups

  name                = each.key
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# ----------------------------------------------------------------------------
# NSG Rules
# ----------------------------------------------------------------------------
# Security rules define what traffic is allowed or denied:
# - Direction: Inbound (to VM) or Outbound (from VM)
# - Access: Allow or Deny
# - Protocol: Tcp, Udp, Icmp, or * (all)
# - Source/Destination: Can be IP ranges, service tags, or application security groups
# - Priority: 100-4096 (lower = higher priority)
# ----------------------------------------------------------------------------
resource "azurerm_network_security_rule" "main" {
  for_each = {
    for pair in flatten([
      for nsg_name, nsg_config in var.network_security_groups : [
        for rule in nsg_config.rules : {
          key  = "${nsg_name}-${rule.name}"
          nsg  = nsg_name
          rule = rule
        }
      ]
    ]) : pair.key => pair
  }

  name                                       = each.value.rule.name
  priority                                   = each.value.rule.priority
  direction                                  = each.value.rule.direction
  access                                     = each.value.rule.access
  protocol                                   = each.value.rule.protocol
  source_port_range                          = each.value.rule.source_port_range
  source_port_ranges                         = length(each.value.rule.source_port_ranges) > 0 ? each.value.rule.source_port_ranges : null
  destination_port_range                     = each.value.rule.destination_port_range
  destination_port_ranges                    = length(each.value.rule.destination_port_ranges) > 0 ? each.value.rule.destination_port_ranges : null
  source_address_prefix                      = each.value.rule.source_address_prefix
  source_address_prefixes                    = length(each.value.rule.source_address_prefixes) > 0 ? each.value.rule.source_address_prefixes : null
  source_application_security_group_ids      = length(each.value.rule.source_application_security_group_ids) > 0 ? each.value.rule.source_application_security_group_ids : null
  destination_address_prefix                 = each.value.rule.destination_address_prefix
  destination_address_prefixes               = length(each.value.rule.destination_address_prefixes) > 0 ? each.value.rule.destination_address_prefixes : null
  destination_application_security_group_ids = length(each.value.rule.destination_application_security_group_ids) > 0 ? each.value.rule.destination_application_security_group_ids : null
  resource_group_name                        = var.resource_group_name
  network_security_group_name                = azurerm_network_security_group.main[each.value.nsg].name
}

# ----------------------------------------------------------------------------
# NSG-Subnet Associations
# ----------------------------------------------------------------------------
# Associates NSGs to subnets. When associated:
# - All VMs in the subnet inherit the NSG rules
# - Rules are evaluated at the network interface level
# - You can also associate NSGs directly to network interfaces (more granular)
# ----------------------------------------------------------------------------
resource "azurerm_subnet_network_security_group_association" "main" {
  for_each = {
    for pair in flatten([
      for nsg_name, nsg_config in var.network_security_groups : [
        for subnet_name in nsg_config.associate_to_subnets : {
          key    = "${nsg_name}-${subnet_name}"
          nsg    = nsg_name
          subnet = subnet_name
        }
      ]
    ]) : pair.key => pair
  }

  subnet_id                 = azurerm_subnet.main[each.value.subnet].id
  network_security_group_id = azurerm_network_security_group.main[each.value.nsg].id
}

# ----------------------------------------------------------------------------
# Route Tables
# ----------------------------------------------------------------------------
# Route tables control where network traffic is directed:
# - System routes: Automatically created (local VNet, internet, etc.)
# - Custom routes: User-defined routes that override system routes
# - Next hop types:
#   * VirtualNetworkGateway: Route to VPN/ExpressRoute gateway
#   * VnetLocal: Route to resources in the same VNet
#   * Internet: Route to internet
#   * VirtualAppliance: Route to a VM acting as a firewall/NAT (e.g., Azure Firewall)
#   * None: Drop traffic (blackhole route)
# ----------------------------------------------------------------------------
resource "azurerm_route_table" "main" {
  for_each = var.route_tables

  name                = each.key
  location            = var.location
  resource_group_name = var.resource_group_name
  # Note: BGP route propagation control may vary by Azure provider version
  # By default, BGP routes from gateways are propagated

  tags = var.tags
}

# ----------------------------------------------------------------------------
# Routes
# ----------------------------------------------------------------------------
# Custom routes define specific routing behavior:
# - Address prefix: Destination network (CIDR notation)
# - Next hop type: Where to send the traffic
# - Next hop IP: Required for VirtualAppliance type
# 
# Common use cases:
# - Force all internet traffic through Azure Firewall (0.0.0.0/0 → VirtualAppliance)
# - Route specific networks through VPN gateway
# - Blackhole malicious traffic (route to None)
# ----------------------------------------------------------------------------
resource "azurerm_route" "main" {
  for_each = {
    for pair in flatten([
      for rt_name, rt_config in var.route_tables : [
        for route in rt_config.routes : {
          key   = "${rt_name}-${route.name}"
          rt    = rt_name
          route = route
        }
      ]
    ]) : pair.key => pair
  }

  name                   = each.value.route.name
  resource_group_name    = var.resource_group_name
  route_table_name       = azurerm_route_table.main[each.value.rt].name
  address_prefix         = each.value.route.address_prefix
  next_hop_type          = each.value.route.next_hop_type
  next_hop_in_ip_address = each.value.route.next_hop_in_ip_address
}

# ----------------------------------------------------------------------------
# Route Table-Subnet Associations
# ----------------------------------------------------------------------------
# Associates route tables to subnets:
# - All traffic from VMs in the subnet uses the route table
# - Routes are evaluated in order (most specific first)
# - System routes are always present (cannot be removed)
# ----------------------------------------------------------------------------
resource "azurerm_subnet_route_table_association" "main" {
  for_each = {
    for pair in flatten([
      for rt_name, rt_config in var.route_tables : [
        for subnet_name in rt_config.associate_to_subnets : {
          key    = "${rt_name}-${subnet_name}"
          rt     = rt_name
          subnet = subnet_name
        }
      ]
    ]) : pair.key => pair
  }

  subnet_id      = azurerm_subnet.main[each.value.subnet].id
  route_table_id = azurerm_route_table.main[each.value.rt].id
}

