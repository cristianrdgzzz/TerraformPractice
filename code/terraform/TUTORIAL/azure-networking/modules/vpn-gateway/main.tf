# ============================================================================
# Azure VPN Gateway Module - Main Configuration
# ============================================================================
# VPN Gateway provides secure connectivity between on-premises networks
# and Azure Virtual Networks via encrypted tunnels over the Internet.
#
# Architecture:
# On-Premises Network
#     ↓
# VPN Device (IPsec/IKE)
#     ↓
# Internet (Encrypted Tunnel)
#     ↓
# VPN Gateway (Azure)
#     ↓
# Azure Virtual Network
# ============================================================================

# ----------------------------------------------------------------------------
# Public IP for VPN Gateway
# ----------------------------------------------------------------------------
# VPN Gateway requires a public IP address for Internet connectivity.
# In active-active mode, two public IPs are required.
# ----------------------------------------------------------------------------
resource "azurerm_public_ip" "main" {
  count = var.active_active ? 2 : 1

  name                = "${var.vpn_gateway_name}-pip-${count.index + 1}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = var.public_ip_configuration.allocation_method
  sku                 = var.public_ip_configuration.sku
  zones               = var.public_ip_configuration.zones

  tags = var.tags
}

# ----------------------------------------------------------------------------
# VPN Gateway
# ----------------------------------------------------------------------------
# VPN Gateway provides:
# - Site-to-Site (S2S) VPN: Connect on-premises networks
# - Point-to-Site (P2S) VPN: Connect individual clients
# - VNet-to-VNet: Connect Azure Virtual Networks
# - ExpressRoute failover: Backup connectivity
#
# SKU Options:
# - Basic: 100 Mbps, 10 tunnels, no BGP (development/testing only)
# - VpnGw1: 650 Mbps, 30 tunnels, BGP support
# - VpnGw2: 1 Gbps, 30 tunnels, BGP support
# - VpnGw3: 1.25 Gbps, 30 tunnels, BGP support
# - VpnGw4: 5 Gbps, 100 tunnels, BGP support
# - VpnGw5: 10 Gbps, 100 tunnels, BGP support
#
# VPN Types:
# - RouteBased: Dynamic routing (BGP), recommended
# - PolicyBased: Static routing, limited features
#
# Subnet Requirements:
# - Must be named 'GatewaySubnet'
# - Minimum /27 CIDR (32 IP addresses)
# - For high-performance SKUs: /26 recommended
# ----------------------------------------------------------------------------
resource "azurerm_virtual_network_gateway" "main" {
  name                = var.vpn_gateway_name
  location            = var.location
  resource_group_name = var.resource_group_name
  type                = "Vpn"
  vpn_type            = var.vpn_type
  sku                 = var.sku
  active_active       = var.active_active
  enable_bgp          = var.enable_bgp

  # Gateway IP Configuration (Subnet)
  ip_configuration {
    name                          = var.gateway_ip_configuration.name
    public_ip_address_id          = azurerm_public_ip.main[0].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = var.gateway_ip_configuration.subnet_id
  }

  # Second IP Configuration (for active-active mode)
  dynamic "ip_configuration" {
    for_each = var.active_active ? [1] : []
    content {
      name                          = "${var.gateway_ip_configuration.name}-2"
      public_ip_address_id          = azurerm_public_ip.main[1].id
      private_ip_address_allocation = "Dynamic"
      subnet_id                     = var.gateway_ip_configuration.subnet_id
    }
  }

  # BGP Settings
  dynamic "bgp_settings" {
    for_each = var.enable_bgp && var.bgp_settings != null ? [var.bgp_settings] : []
    content {
      asn         = bgp_settings.value.asn
      peer_weight = bgp_settings.value.peer_weight

      # Peering Addresses
      dynamic "peering_address" {
        for_each = bgp_settings.value.peering_addresses != null ? bgp_settings.value.peering_addresses : []
        content {
          ip_configuration_name = peering_address.value
        }
      }
    }
  }

  # Point-to-Site VPN Configuration
  dynamic "vpn_client_configuration" {
    for_each = var.vpn_client_configuration != null ? [var.vpn_client_configuration] : []
    content {
      address_space = vpn_client_configuration.value.address_space

      # Root Certificates
      dynamic "root_certificate" {
        for_each = vpn_client_configuration.value.root_certificates != null ? vpn_client_configuration.value.root_certificates : []
        content {
          name             = root_certificate.value.name
          public_cert_data = root_certificate.value.public_cert_data
        }
      }

      # Revoked Certificates
      dynamic "revoked_certificate" {
        for_each = vpn_client_configuration.value.revoked_certificates != null ? vpn_client_configuration.value.revoked_certificates : []
        content {
          name       = revoked_certificate.value.name
          thumbprint = revoked_certificate.value.thumbprint
        }
      }

      # RADIUS Server Configuration
      radius_server_address = vpn_client_configuration.value.radius_server_address
      radius_server_secret  = vpn_client_configuration.value.radius_server_secret

      # VPN Client Protocols
      vpn_client_protocols = vpn_client_configuration.value.vpn_client_protocols
    }
  }

  tags = var.tags
}

# ----------------------------------------------------------------------------
# Local Network Gateway (for Site-to-Site VPN)
# ----------------------------------------------------------------------------
# Local Network Gateway represents your on-premises VPN device.
# This is created separately and connected via a connection resource.
# This module doesn't create the connection - it's typically created
# in the example or live configuration.
# ----------------------------------------------------------------------------

