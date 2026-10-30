# ============================================================================
# Azure Traffic Manager Module - Main Configuration
# ============================================================================
# Traffic Manager is a DNS-based traffic load balancer that distributes
# traffic to endpoints based on routing methods.
#
# Architecture:
# DNS Query (www.example.com)
#     ↓
# Traffic Manager (DNS Response)
#     ↓
# Route to Endpoint (based on routing method)
#     ↓
# Endpoint (Application/Service)
# ============================================================================

# ----------------------------------------------------------------------------
# Traffic Manager Profile
# ----------------------------------------------------------------------------
# Traffic Manager Profile is a DNS-based load balancer that:
# - Distributes traffic across multiple endpoints
# - Provides high availability through automatic failover
# - Routes traffic based on various methods (performance, priority, etc.)
# - Monitors endpoint health
#
# Routing Methods:
# - Priority: Failover (primary → secondary)
# - Weighted: Distribute by weight percentage
# - Performance: Route to lowest latency endpoint
# - Geographic: Route based on user location
# - Subnet: Route based on source IP subnet
# - MultiValue: Return multiple healthy endpoints
# ----------------------------------------------------------------------------
resource "azurerm_traffic_manager_profile" "main" {
  name                   = var.traffic_manager_profile_name
  resource_group_name    = var.resource_group_name
  traffic_routing_method = var.traffic_routing_method

  # DNS Configuration
  dns_config {
    relative_name = var.dns_config.relative_name
    ttl           = var.dns_config.ttl
  }

  # Monitor Configuration
  monitor_config {
    protocol                     = var.monitor_config.protocol
    port                         = var.monitor_config.port
    path                         = var.monitor_config.path
    interval_in_seconds          = var.monitor_config.interval_in_seconds
    timeout_in_seconds           = var.monitor_config.timeout_in_seconds
    tolerated_number_of_failures = var.monitor_config.tolerated_number_of_failures

    dynamic "expected_status_code_ranges" {
      for_each = var.monitor_config.expected_status_code_ranges != null ? var.monitor_config.expected_status_code_ranges : []
      content {
        min = split("-", expected_status_code_ranges.value)[0]
        max = split("-", expected_status_code_ranges.value)[1]
      }
    }
  }

  tags = var.tags
}

# ----------------------------------------------------------------------------
# Traffic Manager Endpoints
# ----------------------------------------------------------------------------
# Endpoints are the destinations that Traffic Manager routes traffic to.
# They can be:
# - Azure endpoints: Azure resources (Public IPs, App Services, etc.)
# - External endpoints: External services
# - Nested endpoints: Other Traffic Manager profiles
# ----------------------------------------------------------------------------
resource "azurerm_traffic_manager_endpoint" "main" {
  for_each = {
    for endpoint in var.endpoints : endpoint.name => endpoint
  }

  name                = each.value.name
  resource_group_name = var.resource_group_name
  profile_name        = azurerm_traffic_manager_profile.main.name
  type                = each.value.type
  target_resource_id  = each.value.target_resource_id
  target              = each.value.target
  priority            = each.value.priority
  weight              = each.value.weight
  enabled             = each.value.enabled
  geo_mappings        = each.value.geo_mappings
  subnet_ids          = each.value.subnet_ids

  # Custom Headers
  dynamic "custom_header" {
    for_each = each.value.custom_headers != null ? each.value.custom_headers : []
    content {
      name  = custom_header.value.name
      value = custom_header.value.value
    }
  }
}

