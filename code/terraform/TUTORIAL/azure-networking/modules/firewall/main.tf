# ============================================================================
# Azure Firewall Module - Main Configuration
# ============================================================================
# Azure Firewall provides:
# - Network filtering (Layer 3/4)
# - Application filtering (FQDN-based, Layer 7)
# - NAT (DNAT)
# - Threat Intelligence integration
# - Built-in high availability
# - Auto-scaling (up to 30,000 connections/second)
#
# Architecture:
# Internet
#     ↓
# Public IP (Firewall)
#     ↓
# Azure Firewall
#     ├── NAT Rules (DNAT)
#     ├── Network Rules (IP/Port filtering)
#     └── Application Rules (FQDN filtering)
#     ↓
# Private Subnet (VMs)
# ============================================================================

# ----------------------------------------------------------------------------
# Azure Firewall
# ----------------------------------------------------------------------------
# Azure Firewall is a managed firewall service that provides:
# - Stateful packet inspection
# - Network and application-level filtering
# - Built-in high availability (no configuration needed)
# - Auto-scaling based on traffic
# - Integration with Azure Monitor and Log Analytics
#
# SKU Options:
# - Standard: Basic firewall features, up to 2.5 Gbps throughput
# - Premium: Advanced features (TLS inspection, IDPS), up to 30 Gbps throughput
#
# Subnet Requirements:
# - Must be named 'AzureFirewallSubnet'
# - Minimum /26 CIDR (64 IP addresses)
# - For Premium: Also requires 'AzureFirewallManagementSubnet' (/26)
# ----------------------------------------------------------------------------
resource "azurerm_firewall" "main" {
  name                = var.firewall_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = var.sku_name
  sku_tier            = var.sku_tier
  firewall_policy_id  = null # Using inline rules, not firewall policy

  # IP Configuration: Defines the firewall's public IP
  # The firewall uses this IP for outbound internet access
  ip_configuration {
    name                 = "firewall-ip-config"
    subnet_id            = var.firewall_subnet_id
    public_ip_address_id = var.public_ip_address_id
  }

  # Management IP Configuration: Required for Premium SKU
  # Provides management access to the firewall
  dynamic "management_ip_configuration" {
    for_each = var.management_subnet_id != null ? [1] : []
    content {
      name                 = "management-ip-config"
      subnet_id            = var.management_subnet_id
      public_ip_address_id = var.management_public_ip_address_id
    }
  }

  # Availability Zones: For high availability
  # Standard: 1 zone, Premium: All zones (zone-redundant)
  zones = var.zones

  # DNS Settings: Custom DNS servers for FQDN resolution
  # Used by application rules to resolve FQDNs
  dns_servers = var.dns_servers

  # Private IP Ranges: Traffic to these ranges bypasses the firewall
  # Useful for Azure service endpoints, on-premises networks, etc.
  private_ip_ranges = var.private_ip_ranges

  # Threat Intelligence: Blocks traffic from/to known malicious IPs/domains
  # Options:
  # - Alert: Logs but allows traffic
  # - Deny: Blocks traffic
  # - Off: Disabled
  threat_intel_mode = var.threat_intel_mode

  tags = var.tags
}

# ----------------------------------------------------------------------------
# Network Rule Collections
# ----------------------------------------------------------------------------
# Network rules filter traffic based on:
# - Source IP addresses
# - Destination IP addresses
# - Destination ports
# - Protocols (TCP, UDP, ICMP, Any)
#
# Use Cases:
# - Allow/deny access to specific IP ranges
# - Control access to on-premises resources
# - Filter traffic between subnets
#
# Priority: Lower number = higher priority (evaluated first)
# Action: Allow or Deny
# ----------------------------------------------------------------------------
resource "azurerm_firewall_network_rule_collection" "main" {
  for_each = {
    for collection in var.network_rule_collections : collection.name => collection
  }

  name                = each.value.name
  azure_firewall_name = azurerm_firewall.main.name
  resource_group_name = var.resource_group_name
  priority            = each.value.priority
  action              = each.value.action

  # Network Rules
  dynamic "rule" {
    for_each = each.value.rules
    content {
      name                  = rule.value.name
      source_addresses      = rule.value.source_addresses
      destination_addresses = rule.value.destination_addresses
      destination_ports     = rule.value.destination_ports
      protocols             = rule.value.protocols
    }
  }
}

# ----------------------------------------------------------------------------
# Application Rule Collections
# ----------------------------------------------------------------------------
# Application rules filter traffic based on:
# - Source IP addresses
# - Target FQDNs (Fully Qualified Domain Names)
# - Protocols (HTTP, HTTPS, MSSQL)
#
# Use Cases:
# - Allow access to specific websites (e.g., *.microsoft.com)
# - Block access to social media sites
# - Control access to Azure services (e.g., *.blob.core.windows.net)
#
# FQDN Wildcards:
# - *.example.com matches example.com, www.example.com, api.example.com
# - example.com matches only example.com
#
# Note: Application rules require DNS resolution. Ensure DNS is configured.
# ----------------------------------------------------------------------------
resource "azurerm_firewall_application_rule_collection" "main" {
  for_each = {
    for collection in var.application_rule_collections : collection.name => collection
  }

  name                = each.value.name
  azure_firewall_name = azurerm_firewall.main.name
  resource_group_name = var.resource_group_name
  priority            = each.value.priority
  action              = each.value.action

  # Application Rules
  dynamic "rule" {
    for_each = each.value.rules
    content {
      name             = rule.value.name
      source_addresses = rule.value.source_addresses
      target_fqdns     = rule.value.target_fqdns

      dynamic "protocol" {
        for_each = [rule.value.protocol]
        content {
          type = protocol.value.type
          port = protocol.value.port
        }
      }
    }
  }
}

# ----------------------------------------------------------------------------
# NAT Rule Collections
# ----------------------------------------------------------------------------
# NAT rules perform Destination NAT (DNAT):
# - Translate public IP:port → private IP:port
# - Allows external clients to access internal resources
#
# Use Cases:
# - Expose internal web servers to the internet
# - Port forwarding for specific services
# - Load balancing (combined with multiple NAT rules)
#
# Example:
# - External: 20.1.2.3:80 → Internal: 10.0.1.10:8080
# - Client connects to firewall's public IP, firewall forwards to internal server
#
# Note: NAT rules take precedence over network/application rules
# ----------------------------------------------------------------------------
resource "azurerm_firewall_nat_rule_collection" "main" {
  for_each = {
    for collection in var.nat_rule_collections : collection.name => collection
  }

  name                = each.value.name
  azure_firewall_name = azurerm_firewall.main.name
  resource_group_name = var.resource_group_name
  priority            = each.value.priority
  action              = "Dnat" # NAT rules always perform DNAT

  # NAT Rules
  dynamic "rule" {
    for_each = each.value.rules
    content {
      name                = rule.value.name
      source_addresses    = rule.value.source_addresses
      destination_address = rule.value.destination_address
      destination_ports   = rule.value.destination_ports
      translated_address  = rule.value.translated_address
      translated_port     = rule.value.translated_port
      protocols           = rule.value.protocols
    }
  }
}

