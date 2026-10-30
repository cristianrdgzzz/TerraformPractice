# ============================================================================
# Azure Network Watcher Module - Main Configuration
# ============================================================================
# Network Watcher provides tools to monitor, diagnose, and view metrics
# for your Azure network infrastructure.
#
# Key Features:
# - Topology visualization
# - Connection monitoring
# - Packet capture
# - IP flow verify
# - Next hop analysis
# - VPN troubleshooting
# - NSG flow logs
# ============================================================================

# ----------------------------------------------------------------------------
# Network Watcher
# ----------------------------------------------------------------------------
# Network Watcher is automatically created in each Azure region.
# However, we can explicitly create it to ensure it exists and configure it.
#
# Note: Network Watcher is a regional service. One instance per region.
# The name is typically 'NetworkWatcher_{region}' (e.g., 'NetworkWatcher_eastus').
# ----------------------------------------------------------------------------
resource "azurerm_network_watcher" "main" {
  name                = var.network_watcher_name != null ? var.network_watcher_name : "NetworkWatcher_${replace(var.location, " ", "")}"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# ----------------------------------------------------------------------------
# NSG Flow Logs
# ----------------------------------------------------------------------------
# NSG Flow Logs capture information about IP traffic flowing through NSGs.
# They help with:
# - Network monitoring
# - Security analysis
# - Compliance
# - Troubleshooting
#
# Flow Log Versions:
# - Version 1: Legacy format
# - Version 2: Enhanced format with additional fields
# ----------------------------------------------------------------------------
resource "azurerm_network_watcher_flow_log" "main" {
  for_each = var.enable_flow_logs ? var.flow_logs : {}

  name                      = each.key
  network_watcher_name      = azurerm_network_watcher.main.name
  resource_group_name       = var.resource_group_name
  network_security_group_id = each.value.network_security_group_id
  storage_account_id        = each.value.storage_account_id
  enabled                   = each.value.enabled
  retention_policy {
    enabled = each.value.retention_days > 0
    days    = each.value.retention_days
  }

  # Traffic Analytics (optional)
  dynamic "traffic_analytics" {
    for_each = each.value.traffic_analytics != null ? [each.value.traffic_analytics] : []
    content {
      enabled               = traffic_analytics.value.enabled
      workspace_id          = traffic_analytics.value.workspace_id
      workspace_region      = traffic_analytics.value.workspace_region
      workspace_resource_id = traffic_analytics.value.workspace_resource_id
      interval_in_minutes   = traffic_analytics.value.interval_in_minutes
    }
  }

  tags = merge(var.tags, each.value.tags)
}

# ----------------------------------------------------------------------------
# Connection Monitors
# ----------------------------------------------------------------------------
# Connection Monitors test connectivity between endpoints and provide:
# - Connectivity monitoring
# - Latency measurement
# - Path analysis
# - Troubleshooting information
#
# Connection Monitors use endpoints (source and destination) and test
# configurations to monitor network connectivity.
# ----------------------------------------------------------------------------
resource "azurerm_network_connection_monitor" "main" {
  for_each = var.connection_monitors

  name               = each.value.name
  network_watcher_id = azurerm_network_watcher.main.id
  location           = var.location
  notes              = each.value.notes

  # Source endpoint
  endpoint {
    name = "${each.key}-source"

    target_resource_id = each.value.source.virtual_machine_id
    address            = each.value.source.address
  }

  # Destination endpoint
  endpoint {
    name    = "${each.key}-destination"
    address = each.value.destination.address
  }

  # Test configurations
  dynamic "test_configuration" {
    for_each = each.value.test_configurations
    content {
      name                      = test_configuration.value.name
      protocol                  = test_configuration.value.protocol
      test_frequency_in_seconds = test_configuration.value.test_frequency_in_seconds
      preferred_ip_version      = test_configuration.value.preferred_ip_version

      dynamic "tcp_configuration" {
        for_each = test_configuration.value.tcp_configuration != null ? [test_configuration.value.tcp_configuration] : []
        content {
          port                = tcp_configuration.value.port
          trace_route_enabled = !tcp_configuration.value.disable_trace_route
        }
      }

      dynamic "http_configuration" {
        for_each = test_configuration.value.http_configuration != null ? [test_configuration.value.http_configuration] : []
        content {
          port                     = http_configuration.value.port
          method                   = http_configuration.value.method
          path                     = http_configuration.value.path
          request_headers          = http_configuration.value.request_headers
          valid_status_code_ranges = http_configuration.value.valid_status_code_ranges
          prefer_https             = http_configuration.value.prefer_https
        }
      }

      dynamic "icmp_configuration" {
        for_each = test_configuration.value.icmp_configuration != null ? [test_configuration.value.icmp_configuration] : []
        content {
          trace_route_enabled = !icmp_configuration.value.disable_trace_route
        }
      }
    }
  }

  # Test groups
  test_group {
    name                     = "${each.key}-test-group"
    destination_endpoints    = ["${each.key}-destination"]
    source_endpoints         = ["${each.key}-source"]
    test_configuration_names = [for config in each.value.test_configurations : config.name]
    disable                  = each.value.enabled != null ? !each.value.enabled : false
  }

  tags = merge(var.tags, each.value.tags != null ? each.value.tags : {})
}

