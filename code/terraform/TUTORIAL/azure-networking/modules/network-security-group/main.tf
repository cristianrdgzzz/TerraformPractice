# ============================================================================
# Azure Network Security Group Module - Main Configuration
# ============================================================================
# This module creates Azure Network Security Groups (NSGs) with:
# - Network Security Groups
# - Security rules (inbound and outbound)
# - Optional subnet associations
# - Optional network interface associations
#
# Architecture:
# NSG
#   ├── Inbound Rules (Allow/Deny traffic TO resources)
#   ├── Outbound Rules (Allow/Deny traffic FROM resources)
#   └── Associations (Subnets or Network Interfaces)
# ============================================================================

# ----------------------------------------------------------------------------
# Network Security Group
# ----------------------------------------------------------------------------
# NSGs act as a distributed firewall at the network level:
# - Rules are evaluated at the VM's network interface level
# - Rules can be inbound or outbound
# - Rules have priorities (lower number = higher priority)
# - Default rules allow all outbound and deny all inbound (except VNet traffic)
# - NSGs can be associated to subnets or network interfaces
#
# Key Characteristics:
# - Layer 4 (TCP/UDP/ICMP) filtering
# - 5-tuple matching: Source IP, Source Port, Destination IP, Destination Port, Protocol
# - Stateful: Return traffic is automatically allowed
# - Default rules: Cannot be deleted, but can be overridden
#
# Default Rules:
# - AllowVNetInBound: Allow all inbound traffic from VNet
# - AllowAzureLoadBalancerInBound: Allow inbound from Azure Load Balancer
# - DenyAllInBound: Deny all other inbound traffic
# - AllowVNetOutBound: Allow all outbound traffic to VNet
# - AllowInternetOutBound: Allow all outbound traffic to Internet
# - DenyAllOutBound: Deny all other outbound traffic
# ----------------------------------------------------------------------------
resource "azurerm_network_security_group" "main" {
  name                = var.nsg_name
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# ----------------------------------------------------------------------------
# Security Rules
# ----------------------------------------------------------------------------
# Security rules define what traffic is allowed or denied:
# - Direction: Inbound (to VM) or Outbound (from VM)
# - Access: Allow or Deny
# - Protocol: Tcp, Udp, Icmp, or * (all)
# - Source/Destination: Can be IP ranges, service tags, or application security groups
# - Priority: 100-4096 (lower = higher priority)
#
# Rule Evaluation:
# - Rules are evaluated in priority order (lowest number first)
# - First matching rule is applied
# - If no rule matches, default rules apply
#
# Service Tags:
# - VirtualNetwork: All IP addresses in the VNet
# - Internet: All public IP addresses
# - AzureLoadBalancer: Azure Load Balancer
# - Storage: Azure Storage service
# - Sql: Azure SQL Database
# - And many more...
#
# Application Security Groups (ASG):
# - Logical grouping of VMs
# - Rules can reference ASGs instead of IP addresses
# - Simplifies rule management for dynamic environments
# ----------------------------------------------------------------------------
resource "azurerm_network_security_rule" "main" {
  for_each = {
    for rule in var.security_rules : rule.name => rule
  }

  name                                       = each.value.name
  priority                                   = each.value.priority
  direction                                  = each.value.direction
  access                                     = each.value.access
  protocol                                   = each.value.protocol
  source_port_range                          = each.value.source_port_range
  source_port_ranges                         = length(each.value.source_port_ranges) > 0 ? each.value.source_port_ranges : null
  destination_port_range                     = each.value.destination_port_range
  destination_port_ranges                    = length(each.value.destination_port_ranges) > 0 ? each.value.destination_port_ranges : null
  source_address_prefix                      = each.value.source_address_prefix
  source_address_prefixes                    = length(each.value.source_address_prefixes) > 0 ? each.value.source_address_prefixes : null
  source_application_security_group_ids      = length(each.value.source_application_security_group_ids) > 0 ? each.value.source_application_security_group_ids : null
  destination_address_prefix                 = each.value.destination_address_prefix
  destination_address_prefixes               = length(each.value.destination_address_prefixes) > 0 ? each.value.destination_address_prefixes : null
  destination_application_security_group_ids = length(each.value.destination_application_security_group_ids) > 0 ? each.value.destination_application_security_group_ids : null
  resource_group_name                        = var.resource_group_name
  network_security_group_name                = azurerm_network_security_group.main.name
  description                                = each.value.description
}

# ----------------------------------------------------------------------------
# NSG-Subnet Associations
# ----------------------------------------------------------------------------
# Associates NSGs to subnets. When associated:
# - All VMs in the subnet inherit the NSG rules
# - Rules are evaluated at the network interface level
# - You can also associate NSGs directly to network interfaces (more granular)
#
# Association Priority:
# - If NSG is associated to both subnet and NIC, both rule sets apply
# - Rules are evaluated in order: Subnet NSG → NIC NSG
# - Most restrictive rule wins
# ----------------------------------------------------------------------------
resource "azurerm_subnet_network_security_group_association" "main" {
  for_each = toset(var.associate_to_subnets)

  subnet_id                 = each.value
  network_security_group_id = azurerm_network_security_group.main.id
}


