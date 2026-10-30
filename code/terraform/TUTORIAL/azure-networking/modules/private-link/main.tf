# ============================================================================
# Azure Private Link Module - Main Configuration
# ============================================================================
# Private Link provides:
# - Private connectivity to Azure services
# - Private connectivity to customer-owned services
# - No exposure to the Internet
# - Automatic DNS integration
# - Global reach
#
# Architecture:
# Virtual Network
#     ↓
# Private Endpoint (Private IP)
#     ↓
# Private Link Service / Azure Service
# ============================================================================

# ----------------------------------------------------------------------------
# Private Endpoints
# ----------------------------------------------------------------------------
# Private Endpoints provide private IP addresses for Azure services.
# Traffic stays on the Azure backbone network and never traverses the Internet.
#
# Key Features:
# - Private IP addresses in your VNet
# - Automatic DNS integration
# - No public exposure
# - Works with: Storage, SQL, Key Vault, App Service, and more
# ----------------------------------------------------------------------------
resource "azurerm_private_endpoint" "main" {
  for_each = var.private_endpoints

  name                = each.value.name
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = each.value.subnet_id

  # Private Service Connection
  private_service_connection {
    name                           = each.value.private_service_connection.name
    private_connection_resource_id = each.value.private_service_connection.private_connection_resource_id
    subresource_names              = each.value.private_service_connection.subresource_names
    is_manual_connection           = each.value.private_service_connection.is_manual_connection
    request_message                = each.value.private_service_connection.request_message
  }

  # Private DNS Zone Group (for automatic DNS integration)
  dynamic "private_dns_zone_group" {
    for_each = each.value.private_dns_zone_group != null ? [each.value.private_dns_zone_group] : []
    content {
      name                 = private_dns_zone_group.value.name
      private_dns_zone_ids = private_dns_zone_group.value.private_dns_zone_ids
    }
  }

  tags = merge(var.tags, each.value.tags)
}

# ----------------------------------------------------------------------------
# Private Link Services
# ----------------------------------------------------------------------------
# Private Link Services expose your own services (e.g., applications behind
# a Load Balancer) via Private Link, allowing other VNets to connect privately.
#
# Key Features:
# - Expose your services via Private Link
# - Control who can connect (approval required)
# - Private connectivity for consumers
# - Works with Load Balancer (Standard SKU)
# ----------------------------------------------------------------------------
resource "azurerm_private_link_service" "main" {
  for_each = var.private_link_services

  name                = each.value.name
  location            = var.location
  resource_group_name = var.resource_group_name

  # Load Balancer Frontend IP Configurations
  load_balancer_frontend_ip_configuration_ids = each.value.load_balancer_frontend_ip_configuration_ids

  # NAT IP Configurations
  dynamic "nat_ip_configuration" {
    for_each = each.value.nat_ip_configurations
    content {
      name                       = nat_ip_configuration.value.name
      private_ip_address_version = nat_ip_configuration.value.private_ip_address_version
      subnet_id                  = nat_ip_configuration.value.subnet_id
      primary                    = nat_ip_configuration.value.primary
    }
  }

  # Auto-approval subscriptions (connections from these are auto-approved)
  auto_approval_subscription_ids = each.value.auto_approval_subscription_ids

  # Visibility subscriptions (these can see the service)
  visibility_subscription_ids = each.value.visibility_subscription_ids

  tags = merge(var.tags, each.value.tags)
}

