# ============================================================================
# Azure Firewall Manager Module - Main Configuration
# ============================================================================
# Firewall Manager provides centralized security policy management for
# Azure Firewall across multiple Virtual Networks and Virtual WAN hubs.
#
# Architecture:
# Firewall Policy (Centralized)
#     ├── Virtual Network 1 (Firewall)
#     ├── Virtual Network 2 (Firewall)
#     └── Virtual WAN Hub (Firewall)
# ============================================================================

# ----------------------------------------------------------------------------
# Firewall Policy
# ----------------------------------------------------------------------------
# Firewall Policy is a centralized security policy that can be applied to
# multiple Azure Firewall instances. It provides:
# - Centralized rule management
# - Rule collection groups
# - Threat Intelligence
# - DNS settings
# - TLS inspection (Premium SKU)
#
# SKU Options:
# - Standard: Basic features
# - Premium: Advanced features (TLS inspection, IDPS, URL filtering)
# ----------------------------------------------------------------------------
resource "azurerm_firewall_policy" "main" {
  name                = var.firewall_policy_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.sku

  # Threat Intelligence
  threat_intelligence_mode = var.threat_intelligence_mode
  threat_intelligence_allowlist {
    ip_addresses = var.threat_intelligence_allowlist
  }

  # DNS Settings
  dns {
    servers                   = var.dns_settings.servers
    proxy_enabled             = var.dns_settings.proxy_enabled
    network_rule_fqdn_enabled = var.dns_settings.network_rule_fqdn_enabled
  }

  tags = var.tags
}

# ----------------------------------------------------------------------------
# Firewall Policy Rule Collection Groups
# ----------------------------------------------------------------------------
# Rule Collection Groups organize firewall rules for easier management.
# They contain:
# - Network Rule Collections (Layer 3/4 filtering)
# - Application Rule Collections (FQDN filtering)
# - NAT Rule Collections (DNAT)
# ----------------------------------------------------------------------------
resource "azurerm_firewall_policy_rule_collection_group" "main" {
  for_each = var.rule_collection_groups

  name               = each.key
  firewall_policy_id = azurerm_firewall_policy.main.id
  priority           = each.value.priority

  # Network Rule Collections
  dynamic "network_rule_collection" {
    for_each = each.value.network_rule_collections != null ? each.value.network_rule_collections : []
    content {
      name     = network_rule_collection.value.name
      priority = network_rule_collection.value.priority
      action   = network_rule_collection.value.action

      dynamic "rule" {
        for_each = network_rule_collection.value.rules
        content {
          name                  = rule.value.name
          protocols             = rule.value.protocols
          source_addresses      = rule.value.source_addresses
          destination_addresses = rule.value.destination_addresses
          destination_fqdns     = rule.value.destination_fqdns
          destination_ports     = rule.value.destination_ports
        }
      }
    }
  }

  # Application Rule Collections
  dynamic "application_rule_collection" {
    for_each = each.value.application_rule_collections != null ? each.value.application_rule_collections : []
    content {
      name     = application_rule_collection.value.name
      priority = application_rule_collection.value.priority
      action   = application_rule_collection.value.action

      dynamic "rule" {
        for_each = application_rule_collection.value.rules
        content {
          name             = rule.value.name
          source_addresses = rule.value.source_addresses
          source_ip_groups = rule.value.source_ip_groups
          target_fqdns     = rule.value.target_fqdns
          fqdn_tags        = rule.value.fqdn_tags

          dynamic "protocols" {
            for_each = rule.value.protocols
            content {
              type = protocols.value.type
              port = protocols.value.port
            }
          }
        }
      }
    }
  }

  # NAT Rule Collections
  dynamic "nat_rule_collection" {
    for_each = each.value.nat_rule_collections != null ? each.value.nat_rule_collections : []
    content {
      name     = nat_rule_collection.value.name
      priority = nat_rule_collection.value.priority
      action   = nat_rule_collection.value.action

      dynamic "rule" {
        for_each = nat_rule_collection.value.rules
        content {
          name                = rule.value.name
          protocols           = rule.value.protocols
          source_addresses    = rule.value.source_addresses
          destination_address = rule.value.destination_address
          destination_ports   = rule.value.destination_ports
          translated_address  = rule.value.translated_address
          translated_port     = rule.value.translated_port
        }
      }
    }
  }
}

