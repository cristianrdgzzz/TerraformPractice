# ============================================================================
# Azure DDoS Protection Module - Main Configuration
# ============================================================================
# DDoS Protection provides protection against distributed denial-of-service attacks.
#
# Protection Tiers:
# - Basic: Always-on, automatic mitigation (free)
# - Standard: Advanced features, attack analytics, cost protection (paid)
#
# Architecture:
# Internet Attack
#     ↓
# DDoS Protection (Automatic Detection)
#     ↓
# Mitigation (Automatic)
#     ↓
# Protected Resources
# ============================================================================

# ----------------------------------------------------------------------------
# DDoS Protection Plan
# ----------------------------------------------------------------------------
# DDoS Protection Plan is a logical grouping of DDoS protection settings.
# It can be associated with multiple Virtual Networks.
#
# SKU Options:
# - Basic: Free, always-on protection, automatic mitigation
# - Standard: Paid, advanced features:
#   - Attack analytics and reporting
#   - Cost protection (waiver for resources scaled due to attack)
#   - DDoS rapid response support
#   - Adaptive tuning
# ----------------------------------------------------------------------------
resource "azurerm_network_ddos_protection_plan" "main" {
  name                = var.ddos_protection_plan_name
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Note: Virtual Networks are associated with the DDoS Protection Plan
# by setting the ddos_protection_plan block in the Virtual Network resource.
# This is typically done in the networking module or VNet configuration.
# The virtual_network_ids variable is provided for reference but the
# association must be done at the VNet level.

