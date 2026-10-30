# ============================================================================
# Azure NAT Gateway Module - Main Configuration
# ============================================================================
# NAT Gateway provides outbound internet connectivity for subnets.
#
# Architecture:
# VMs in Subnet (no public IPs)
#     ↓
# NAT Gateway (uses public IP)
#     ↓
# Internet
#
# Benefits over Load Balancer outbound rules:
# - Simpler configuration (no backend pools needed)
# - Better performance (up to 50 Gbps throughput)
# - More concurrent connections (64,000 per public IP)
# - No SNAT port exhaustion issues
# ============================================================================

# ----------------------------------------------------------------------------
# NAT Gateway
# ----------------------------------------------------------------------------
# NAT Gateway provides outbound SNAT (Source Network Address Translation):
# - VMs without public IPs can access the internet
# - Uses the NAT Gateway's public IP as the source
# - Fully managed service (no VMs to manage)
# - Automatic scaling based on traffic
#
# Use Cases:
# - VMs need to download updates
# - VMs need to call external APIs
# - VMs need to access Azure services
# - Avoid SNAT port exhaustion (common with Load Balancer)
#
# Public IPs:
# - Each public IP supports up to 64,000 concurrent flows
# - Multiple public IPs can be added for more capacity
# - Public IPs must be Standard SKU
#
# Idle Timeout:
# - Default: 4 minutes
# - Range: 4-120 minutes
# - Longer timeout = fewer connection resets, but more resources used
# ----------------------------------------------------------------------------
resource "azurerm_nat_gateway" "main" {
  name                    = var.nat_gateway_name
  location                = var.location
  resource_group_name     = var.resource_group_name
  sku_name                = "Standard" # Only Standard SKU is available
  idle_timeout_in_minutes = var.idle_timeout_in_minutes
  zones                   = var.zones

  # Public IP Addresses: Used for outbound connections
  # Each public IP supports up to 64,000 concurrent flows
  # Multiple IPs can be added for more capacity (up to 16 public IPs)
  # Public IPs must be Standard SKU
  dynamic "public_ip_address_ids" {
    for_each = var.public_ip_address_ids
    content {
      id = public_ip_address_ids.value
    }
  }

  # Public IP Prefix: Alternative to individual public IPs
  # Provides a contiguous range of public IP addresses
  # Useful for predictable outbound IP addresses
  # Can use either public_ip_address_ids or public_ip_prefix_ids (or both)
  dynamic "public_ip_prefix_ids" {
    for_each = var.public_ip_prefix_ids
    content {
      id = public_ip_prefix_ids.value
    }
  }

  tags = var.tags
}

# Validation: Ensure at least one public IP or prefix is provided
# This validation is done at the Terraform level through variable validation
# The resource will fail if neither public_ip_address_ids nor public_ip_prefix_ids are provided

